#!/usr/bin/env python3
"""
Download RPMS KIDS patches from the IHS FTP site, extract their routines
and globals, and commit them into the FOIA-RPMS Packages/ tree.

Usage:
  python3 Scripts/UpdateFromIHS.py [options]

This script:
  1. Scrapes the IHS FTP patches page for the full file listing
  2. Identifies KIDS build files (suffix 'k') and patch notes (suffix 'n')
  3. Filters to patches newer than the repo's last-known state
  4. Downloads KIDS files into a staging area
  5. Parses each KIDS build to extract routines and globals
  6. Places extracted files into the Packages/ tree using Packages.csv
  7. Optionally commits each batch to git

Run from the FOIA-RPMS repo root.

Requires: Python 3.7+, requests (pip install requests)
"""

import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import textwrap
import time
import urllib.parse
import shutil
import tarfile
import zipfile
from datetime import datetime
from pathlib import Path

try:
    import requests
except ImportError:
    print("ERROR: 'requests' package is required. Install with: pip install requests")
    sys.exit(1)

import gzip

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
IHS_FTP_BASE = "https://www.ihs.gov/rpms/applications/ftp/"
PATCHES_DIR = "patches"
FOIA_DIR = "FOIA"
STAGING_DIR = ".ihs-staging"
STATE_FILE = ".ihs-update-state.json"

# IHS file naming patterns:
#   abm_0250.01k    (prefix_version.patchsuffix)
#   absp0100.12k    (prefixversion.patchsuffix)  — no underscore
#   xu__0800.1020k  (prefix__version.patchsuffix) — double underscore
#   ehr_0110.01k    (prefix with digit in name)
PATCH_FILE_RE = re.compile(
    r'^(?P<prefix>[a-z]+)_*(?P<version>\d{4})\.(?P<patchnum>\d+)(?P<suffix>[a-z])(?P<ext>\..*)?$',
    re.IGNORECASE
)

# KIDS install name patterns:
#   **KIDS**:ABM*2.5*1^
#   "ABM*2.5*1"
KIDS_HEADER_RE = re.compile(r'^\*\*KIDS\*\*:(.+?)[\^$]')
KIDS_INSTALL_RE = re.compile(r'^"([A-Z0-9 ]+\*[\d.]+\*\d+)"')

# Routine in KIDS: starts with routine name, ends with blank line
# Global in KIDS: ZWR format lines

# ---------------------------------------------------------------------------
# IHS FTP Scraper
# ---------------------------------------------------------------------------

class IHSScraper:
    """Scrapes the IHS RPMS FTP web interface."""

    def __init__(self, session=None):
        self.session = session or requests.Session()
        self.session.headers.update({
            'User-Agent': 'FOIA-RPMS-Updater/1.0'
        })

    def list_directory(self, folder=""):
        """List files in an IHS FTP directory.

        The IHS site uses a FileShareBrowser plugin. Directory entries are
        rendered as hidden form inputs. File entries have download links.

        Args:
            folder: subdirectory name (e.g. "patches", "FOIA", "archive")

        Returns:
            dict with 'files' (list of {name, url}) and 'dirs' (list of names)
        """
        params = {}
        if folder:
            params['parent'] = ''
            params['fld'] = folder

        resp = self.session.get(IHS_FTP_BASE, params=params, timeout=60)
        resp.raise_for_status()
        html = resp.text

        files = []
        dirs = []

        # Extract file download links
        # Pattern: href="?p=rpms%5C<path>&flname=<filename>&download=1"
        for m in re.finditer(
            r'href="\?p=([^&"]+)&flname=([^&"]+)&download=1"',
            html
        ):
            raw_path = urllib.parse.unquote(m.group(1))
            raw_name = urllib.parse.unquote(m.group(2))
            download_url = f"{IHS_FTP_BASE}?p={m.group(1)}&flname={urllib.parse.quote(raw_name, safe='')}&download=1"
            files.append({
                'name': raw_name,
                'path': raw_path,
                'url': download_url,
            })

        # Extract subdirectory entries
        for m in re.finditer(
            r'<input\s+type="hidden"\s+name="fld"\s+value="([^"]+)"',
            html
        ):
            dirs.append(m.group(1))

        return {'files': files, 'dirs': dirs}

    def download_file(self, url, dest_path, retries=3):
        """Download a file from IHS with retry logic."""
        for attempt in range(retries):
            try:
                resp = self.session.get(url, timeout=120, stream=True)
                resp.raise_for_status()
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                with open(dest_path, 'wb') as f:
                    for chunk in resp.iter_content(chunk_size=8192):
                        f.write(chunk)
                return True
            except (requests.RequestException, IOError) as e:
                if attempt < retries - 1:
                    wait = 2 ** attempt
                    print(f"  Retry {attempt+1}/{retries} after {wait}s: {e}")
                    time.sleep(wait)
                else:
                    print(f"  FAILED to download {url}: {e}")
                    return False


# ---------------------------------------------------------------------------
# Patch File Classifier
# ---------------------------------------------------------------------------

class PatchFile:
    """Represents a parsed IHS patch filename."""

    SUFFIX_NAMES = {
        'k': 'kids',      # KIDS build file
        'n': 'notes',     # Installation notes
        'o': 'other',     # Other documentation
        'p': 'routines',  # Routine transfer file (old format)
        'b': 'globals',   # Global transport (old format)
        'e': 'errata',    # Errata/addendum
        'r': 'readme',    # Readme
    }

    def __init__(self, name, url=None):
        self.name = name
        self.url = url
        self.prefix = None
        self.version = None
        self.patchnum = None
        self.suffix = None
        self.ext = None
        self._parse()

    def _parse(self):
        m = PATCH_FILE_RE.match(self.name)
        if m:
            self.prefix = m.group('prefix').lower()
            self.version = m.group('version')
            self.patchnum = int(m.group('patchnum'))
            self.suffix = m.group('suffix').lower()
            self.ext = m.group('ext') or ''

    @property
    def is_valid(self):
        return self.prefix is not None

    @property
    def is_kids(self):
        return self.suffix == 'k'

    @property
    def is_notes(self):
        return self.suffix == 'n'

    @property
    def patch_id(self):
        """Unique patch identifier: prefix_version.patchnum"""
        if self.is_valid:
            return f"{self.prefix}_{self.version}.{self.patchnum:02d}"
        return None

    @property
    def install_name(self):
        """Convert to RPMS install name format: PREFIX*VER*PATCH"""
        if self.is_valid:
            # Version like "0250" -> "2.5", "0260" -> "2.6"
            major = int(self.version[:2])
            minor = int(self.version[2:])
            ver = f"{major}.{minor}" if minor else f"{major}.0"
            return f"{self.prefix.upper()}*{ver}*{self.patchnum}"
        return None

    @property
    def suffix_type(self):
        return self.SUFFIX_NAMES.get(self.suffix, 'unknown')

    def __repr__(self):
        return f"PatchFile({self.name}, {self.patch_id}, {self.suffix_type})"


# ---------------------------------------------------------------------------
# KIDS File Parser
# ---------------------------------------------------------------------------

class KIDSParser:
    """Parse a KIDS build file and extract routines and globals."""

    def __init__(self, filepath):
        self.filepath = filepath
        self.install_name = None
        self.routines = {}   # name -> content
        self.globals = {}    # global_name -> list of ZWR lines
        self.description = ""

    def parse(self):
        """Parse the KIDS file and extract components."""
        try:
            path_str = str(self.filepath)
            if path_str.endswith('.zip'):
                content = self._read_zip()
                if content is None:
                    return False
            elif path_str.endswith('.tar.gz'):
                content = self._read_targz()
                if content is None:
                    return False
            elif path_str.endswith('.gz'):
                try:
                    with gzip.open(self.filepath, 'rt', encoding='utf-8') as f:
                        content = f.read()
                except UnicodeDecodeError:
                    with gzip.open(self.filepath, 'rt', encoding='latin-1') as f:
                        content = f.read()
            else:
                try:
                    with open(self.filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                except UnicodeDecodeError:
                    with open(self.filepath, 'r', encoding='latin-1') as f:
                        content = f.read()

            lines = content.split('\n')
            self._parse_lines(lines)
            return True
        except Exception as e:
            print(f"  Error parsing {self.filepath}: {e}")
            return False

    def _read_targz(self):
        """Read KIDS content from inside a tar.gz archive."""
        try:
            with tarfile.open(self.filepath, 'r:gz') as tf:
                for member in tf.getmembers():
                    if member.isfile():
                        f = tf.extractfile(member)
                        if f:
                            raw = f.read()
                            try:
                                return raw.decode('utf-8')
                            except UnicodeDecodeError:
                                return raw.decode('latin-1')
        except Exception as e:
            print(f"  Error reading tar.gz {self.filepath}: {e}")
            return None

    def _read_zip(self):
        """Read KIDS content from inside a zip archive."""
        try:
            with zipfile.ZipFile(self.filepath, 'r') as zf:
                names = zf.namelist()
                kids_name = None
                for name in names:
                    lower = name.lower()
                    if lower.endswith('k') and not lower.endswith('/'):
                        kids_name = name
                        break
                if not kids_name:
                    for name in names:
                        if not name.endswith('/'):
                            kids_name = name
                            break
                if not kids_name:
                    print(f"  No files found inside {self.filepath}")
                    return None
                raw = zf.read(kids_name)
                try:
                    return raw.decode('utf-8')
                except UnicodeDecodeError:
                    return raw.decode('latin-1')
        except zipfile.BadZipFile:
            print(f"  Bad zip file: {self.filepath}")
            return None

    def _parse_lines(self, lines):
        """Parse KIDS build file line by line."""
        i = 0
        section = None
        current_routine = None
        routine_lines = []
        current_global = None
        global_lines = []

        while i < len(lines):
            line = lines[i]

            # Detect install name from **KIDS** header
            if line.startswith('**KIDS**:'):
                m = KIDS_HEADER_RE.match(line)
                if m:
                    self.install_name = m.group(1)
            # Also try quoted format
            elif not self.install_name:
                m = KIDS_INSTALL_RE.match(line)
                if m:
                    self.install_name = m.group(1)

            # Detect **INSTALL NAME** section — next line has the name
            if line.startswith('**INSTALL NAME**'):
                section = 'install_name'
                if i + 1 < len(lines) and not self.install_name:
                    self.install_name = lines[i + 1].strip()

            # Section markers
            if line.startswith('**KIDS**:'):
                section = 'kids_header'
            elif line.startswith('**INSTALL NAME**'):
                section = 'install_name'
            elif line == 'ROUTINE':
                # Save any previous routine
                if current_routine and routine_lines:
                    self.routines[current_routine] = '\n'.join(routine_lines)
                section = 'routine_header'
                current_routine = None
                routine_lines = []
            elif line == 'BUILD' or line.startswith('"BLD"'):
                if current_routine and routine_lines:
                    self.routines[current_routine] = '\n'.join(routine_lines)
                    current_routine = None
                    routine_lines = []
                section = 'build'
            elif section == 'routine_header' and line and not line.startswith('"'):
                # In routine section, non-quoted lines after ROUTINE
                # are routine names or content
                pass

            # Detect routine content blocks
            # Routines in KIDS are stored as: "RTN",linenum,0) = "content"
            if '"RTN"' in line and ',0)' in line:
                section = 'routine_data'
                # Extract routine name from "RTN","routinename",linenum,0)
                m2 = re.match(r'"RTN","([^"]+)",(\d+),0\)\s*$', line)
                if m2:
                    rtn_name = m2.group(1)
                    if rtn_name != current_routine:
                        if current_routine and routine_lines:
                            self.routines[current_routine] = '\n'.join(routine_lines)
                        current_routine = rtn_name
                        routine_lines = []
                    # Next line should be the content
                    if i + 1 < len(lines):
                        i += 1
                        routine_lines.append(lines[i])

            # Detect global data blocks
            # Globals in KIDS stored similar to ZWR
            elif '"GLB"' in line or ('"DATA"' in line and 'GLB' in line):
                section = 'global_data'

            # Simple heuristic: lines starting with ^ in certain sections are ZWR
            elif line.startswith('^') and '=' in line:
                # This is a ZWR-format global line
                global_name = line.split('(')[0] if '(' in line else line.split('=')[0]
                if global_name not in self.globals:
                    self.globals[global_name] = []
                self.globals[global_name].append(line)

            i += 1

        # Save last routine
        if current_routine and routine_lines:
            self.routines[current_routine] = '\n'.join(routine_lines)


# ---------------------------------------------------------------------------
# Package Mapper
# ---------------------------------------------------------------------------

class PackageMapper:
    """Map namespace prefixes to package directories using Packages.csv."""

    # Prefixes not in Packages.csv that appear in IHS KIDS patches.
    # These are IHS-specific packages or newer additions.
    IHS_EXTRA_PREFIXES = {
        'BLGU':  ('LAB ACCESSIONING', 'IHS Lab Accessioning'),
        'BMAG':  ('IHS MODS TO IMAGING', 'IHS Mods To Imaging'),
        'BPDM':  ('CONTROLLED DRUG EXPORT SYSTEM', 'Controlled Drug Export System'),
        'BREH':  ('RPMS EHI EXPORT', 'RPMS EHI Export'),
        'BUSR':  ('AUTHORIZATION/SUBSCRIPTION', 'Authorization Subscription'),
        'MAGD':  ('IMAGING', 'Imaging'),
        'MAGI':  ('IMAGING', 'Imaging'),
        'MAGN':  ('IMAGING', 'Imaging'),
    }

    def __init__(self, csv_path):
        self.prefix_to_dir = {}
        self.prefix_to_pkg = {}
        self._load(csv_path)

    def _load(self, csv_path):
        """Load Packages.csv and build the prefix -> directory mapping."""
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            current_pkg = None
            current_dir = None
            for row in reader:
                if row.get('Package Name'):
                    current_pkg = row['Package Name']
                    current_dir = row.get('Directory Name', '').strip()
                prefix = row.get('Prefixes', '').strip()
                if prefix and current_dir:
                    if prefix.startswith('!') or prefix.startswith('-'):
                        continue
                    self.prefix_to_dir[prefix.upper()] = current_dir
                    self.prefix_to_pkg[prefix.upper()] = current_pkg

        # Add IHS-specific prefixes not in Packages.csv
        for prefix, (pkg_name, dir_name) in self.IHS_EXTRA_PREFIXES.items():
            if prefix not in self.prefix_to_dir:
                self.prefix_to_dir[prefix] = dir_name
                self.prefix_to_pkg[prefix] = pkg_name

    def get_package_dir(self, prefix):
        """Get the Packages/ subdirectory for a given namespace prefix."""
        prefix_upper = prefix.upper()
        # Try exact match first
        if prefix_upper in self.prefix_to_dir:
            return self.prefix_to_dir[prefix_upper]

        # Try progressively shorter prefixes
        for length in range(len(prefix_upper), 0, -1):
            candidate = prefix_upper[:length]
            if candidate in self.prefix_to_dir:
                return self.prefix_to_dir[candidate]

        return None

    def get_routine_dir(self, prefix):
        pkg_dir = self.get_package_dir(prefix)
        if pkg_dir:
            return os.path.join('Packages', pkg_dir, 'Routines')
        return os.path.join('Packages', 'Uncategorized', 'Routines')

    def get_global_dir(self, prefix):
        pkg_dir = self.get_package_dir(prefix)
        if pkg_dir:
            return os.path.join('Packages', pkg_dir, 'Globals')
        return os.path.join('Packages', 'Uncategorized', 'Globals')


# ---------------------------------------------------------------------------
# State Tracker
# ---------------------------------------------------------------------------

class UpdateState:
    """Track which patches have already been downloaded/applied."""

    def __init__(self, state_path):
        self.state_path = state_path
        self.downloaded = {}     # patch_id -> {filename, sha256, date}
        self.applied = set()     # set of patch_ids
        self.last_run = None
        self._load()

    def _load(self):
        if os.path.exists(self.state_path):
            with open(self.state_path, 'r') as f:
                data = json.load(f)
                self.downloaded = data.get('downloaded', {})
                self.applied = set(data.get('applied', []))
                self.last_run = data.get('last_run')

    def save(self):
        data = {
            'downloaded': self.downloaded,
            'applied': sorted(list(self.applied)),
            'last_run': datetime.now().isoformat(),
        }
        with open(self.state_path, 'w') as f:
            json.dump(data, f, indent=2)

    def is_downloaded(self, patch_id):
        return patch_id in self.downloaded

    def mark_downloaded(self, patch_id, filename, sha256):
        self.downloaded[patch_id] = {
            'filename': filename,
            'sha256': sha256,
            'date': datetime.now().isoformat(),
        }

    def mark_applied(self, patch_id):
        self.applied.add(patch_id)

    def is_applied(self, patch_id):
        return patch_id in self.applied


# ---------------------------------------------------------------------------
# Main Updater
# ---------------------------------------------------------------------------

class RPMSUpdater:
    """Main orchestrator for downloading and applying IHS patches."""

    def __init__(self, repo_root, args):
        self.repo_root = Path(repo_root).resolve()
        self.args = args
        self.scraper = IHSScraper()
        self.mapper = PackageMapper(self.repo_root / 'Packages.csv')
        self.staging = self.repo_root / STAGING_DIR
        self.state = UpdateState(self.repo_root / STATE_FILE)

    def run(self):
        """Main entry point."""
        print(f"FOIA-RPMS Update Script")
        print(f"Repo root: {self.repo_root}")
        print(f"Staging:   {self.staging}")
        print()

        # Step 1: Scrape the IHS patches listing
        print("=" * 60)
        print("Step 1: Scraping IHS FTP patches listing...")
        print("=" * 60)
        patches_listing = self.scraper.list_directory(PATCHES_DIR)
        all_files = patches_listing['files']
        print(f"  Found {len(all_files)} files in patches/")

        # Also check the FOIA directory
        print("  Checking FOIA directory...")
        foia_listing = self.scraper.list_directory(FOIA_DIR)
        foia_files = foia_listing['files']
        print(f"  Found {len(foia_files)} files in FOIA/")
        all_files.extend(foia_files)

        # Step 2: Classify patch files
        print()
        print("=" * 60)
        print("Step 2: Classifying patch files...")
        print("=" * 60)
        patch_files = []
        kids_files = []
        notes_files = []
        zip_files = []
        other_files = []

        for f in all_files:
            pf = PatchFile(f['name'], f['url'])
            if pf.is_valid:
                patch_files.append(pf)
                if pf.is_kids:
                    kids_files.append(pf)
                elif pf.is_notes:
                    notes_files.append(pf)
                else:
                    other_files.append(pf)
            elif f['name'].endswith('.zip'):
                zip_files.append(f)

        print(f"  Classified patch files: {len(patch_files)}")
        print(f"    KIDS builds:    {len(kids_files)}")
        print(f"    Patch notes:    {len(notes_files)}")
        print(f"    Other:          {len(other_files)}")
        print(f"    Zip archives:   {len(zip_files)}")

        # Group by patch_id to find complete patch sets
        patches_by_id = {}
        for pf in patch_files:
            pid = pf.patch_id
            if pid not in patches_by_id:
                patches_by_id[pid] = {}
            patches_by_id[pid][pf.suffix_type] = pf

        print(f"  Unique patches:   {len(patches_by_id)}")

        # Step 3: Filter to new patches
        print()
        print("=" * 60)
        print("Step 3: Filtering to new/unapplied patches...")
        print("=" * 60)
        new_kids = [
            pf for pf in kids_files
            if not self.state.is_downloaded(pf.patch_id)
        ]

        if self.args.redownload:
            new_kids = kids_files
            print(f"  --redownload: will re-download all {len(new_kids)} KIDS files")
        else:
            print(f"  New KIDS files to download: {len(new_kids)}")
            print(f"  Already downloaded:         {len(kids_files) - len(new_kids)}")

        if not new_kids and not self.args.reapply:
            print("  Nothing new to download.")
            if not self.args.force:
                print("  Use --force to re-process existing downloads.")
                return
            new_kids = [
                pf for pf in kids_files
                if self.state.is_downloaded(pf.patch_id) and
                   not self.state.is_applied(pf.patch_id)
            ]
            print(f"  --force: will re-process {len(new_kids)} unapplied downloads")

        # Step 4: Download
        print()
        print("=" * 60)
        print(f"Step 4: Downloading {len(new_kids)} KIDS files...")
        print("=" * 60)
        os.makedirs(self.staging / 'kids', exist_ok=True)
        os.makedirs(self.staging / 'notes', exist_ok=True)

        downloaded = 0
        failed = 0
        for i, pf in enumerate(sorted(new_kids, key=lambda x: x.patch_id)):
            dest = self.staging / 'kids' / pf.name
            print(f"  [{i+1}/{len(new_kids)}] {pf.name}...", end=' ', flush=True)

            if dest.exists() and not self.args.redownload:
                print("exists")
                sha256 = self._sha256(dest)
                self.state.mark_downloaded(pf.patch_id, pf.name, sha256)
                downloaded += 1
                continue

            if self.args.dry_run:
                print("dry-run")
                downloaded += 1
                continue

            if self.scraper.download_file(pf.url, str(dest)):
                sha256 = self._sha256(dest)
                self.state.mark_downloaded(pf.patch_id, pf.name, sha256)
                downloaded += 1
                print("ok")
            else:
                failed += 1
                print("FAILED")

            # Also download corresponding notes file
            pid = pf.patch_id
            if pid in patches_by_id and 'notes' in patches_by_id[pid]:
                notes_pf = patches_by_id[pid]['notes']
                notes_dest = self.staging / 'notes' / notes_pf.name
                if not notes_dest.exists():
                    self.scraper.download_file(notes_pf.url, str(notes_dest))

            # Rate limit
            if not self.args.dry_run:
                time.sleep(0.5)

        print(f"\n  Downloaded: {downloaded}, Failed: {failed}")

        # Save state after downloading
        self.state.save()

        if self.args.download_only:
            print("\n--download-only: stopping after download.")
            return

        # Step 5: Parse and extract
        print()
        print("=" * 60)
        print("Step 5: Parsing KIDS files and extracting routines/globals...")
        print("=" * 60)

        to_apply = []
        if self.args.reapply:
            # Re-apply all downloaded KIDS
            for pf in sorted(kids_files, key=lambda x: x.patch_id):
                kids_path = self.staging / 'kids' / pf.name
                if kids_path.exists():
                    to_apply.append(pf)
        else:
            for pf in sorted(new_kids, key=lambda x: x.patch_id):
                if not self.state.is_applied(pf.patch_id):
                    kids_path = self.staging / 'kids' / pf.name
                    if kids_path.exists():
                        to_apply.append(pf)

        total_routines = 0
        total_globals = 0
        applied_patches = []

        for i, pf in enumerate(to_apply):
            kids_path = self.staging / 'kids' / pf.name
            print(f"\n  [{i+1}/{len(to_apply)}] Parsing {pf.name} ({pf.install_name})...")

            if self.args.dry_run:
                print("    dry-run: skipping parse")
                continue

            routines_extracted, globals_extracted = self._extract_from_kids(
                kids_path, pf
            )
            total_routines += routines_extracted
            total_globals += globals_extracted

            applied_patches.append(pf)
            self.state.mark_applied(pf.patch_id)
            if routines_extracted > 0 or globals_extracted > 0:
                print(f"    Extracted {routines_extracted} routines, {globals_extracted} globals")
            else:
                print(f"    No extractable routines/globals (may need KIDS install)")

        print(f"\n  Total: {total_routines} routines, {total_globals} globals from {len(applied_patches)} patches")

        # Save state
        self.state.save()

        # Also store the KIDS files themselves in the repo for later KIDS install
        kids_repo_dir = self.repo_root / 'Patches' / 'KIDS'
        notes_repo_dir = self.repo_root / 'Patches' / 'Notes'
        os.makedirs(kids_repo_dir, exist_ok=True)
        os.makedirs(notes_repo_dir, exist_ok=True)

        kids_copied = 0
        for pf in to_apply:
            src = self.staging / 'kids' / pf.name
            # Store decompressed text in the repo, not binary archives
            base_name = pf.name
            for ext in ('.tar.gz', '.gz', '.zip'):
                if base_name.endswith(ext):
                    base_name = base_name[:-len(ext)]
                    break
            dst = kids_repo_dir / base_name
            if src.exists() and not dst.exists():
                try:
                    content = self._read_kids_file(src)
                except Exception as e:
                    print(f"  Warning: failed to decompress {pf.name}: {e}")
                    content = None
                if content is not None:
                    with open(dst, 'w', encoding='utf-8') as f:
                        f.write(content)
                else:
                    # Fallback: copy as-is if we can't read it
                    shutil.copy2(str(src), str(dst))
                kids_copied += 1

            # Copy notes too
            pid = pf.patch_id
            if pid in patches_by_id and 'notes' in patches_by_id[pid]:
                notes_pf = patches_by_id[pid]['notes']
                nsrc = self.staging / 'notes' / notes_pf.name
                ndst = notes_repo_dir / notes_pf.name
                if nsrc.exists() and not ndst.exists():
                    shutil.copy2(str(nsrc), str(ndst))

        if kids_copied:
            print(f"  Copied {kids_copied} KIDS files to Patches/KIDS/")

        # Step 6: Git commit
        if self.args.commit and applied_patches and not self.args.dry_run:
            print()
            print("=" * 60)
            print("Step 6: Committing changes to git...")
            print("=" * 60)
            self._git_commit(applied_patches)

        print()
        print("=" * 60)
        print("Done!")
        print("=" * 60)

    def _read_kids_file(self, kids_path):
        """Read a KIDS file, handling plain text, gzip, and zip compression.

        Returns the file content as a string, or None on failure.
        """
        path_str = str(kids_path)

        if path_str.endswith('.zip'):
            return self._read_zip_kids(kids_path)
        elif path_str.endswith('.tar.gz'):
            return self._read_targz_kids(kids_path)
        elif path_str.endswith('.gz'):
            return self._read_gzip_kids(kids_path)
        else:
            return self._read_plain_kids(kids_path)

    def _read_plain_kids(self, kids_path):
        try:
            with open(kids_path, 'r', encoding='utf-8') as f:
                return f.read()
        except UnicodeDecodeError:
            with open(kids_path, 'r', encoding='latin-1') as f:
                return f.read()

    def _read_gzip_kids(self, kids_path):
        try:
            with gzip.open(kids_path, 'rt', encoding='utf-8') as f:
                return f.read()
        except UnicodeDecodeError:
            with gzip.open(kids_path, 'rt', encoding='latin-1') as f:
                return f.read()

    def _read_targz_kids(self, kids_path):
        """Extract and read a KIDS file from inside a tar.gz archive."""
        try:
            with tarfile.open(kids_path, 'r:gz') as tf:
                # Find the KIDS file inside the tar
                for member in tf.getmembers():
                    if member.isfile():
                        f = tf.extractfile(member)
                        if f:
                            try:
                                return f.read().decode('utf-8')
                            except UnicodeDecodeError:
                                f.seek(0)
                                return f.read().decode('latin-1')
        except Exception as e:
            print(f"    Error reading tar.gz {kids_path}: {e}")
            return None

    def _read_zip_kids(self, kids_path):
        """Extract and read a KIDS file from inside a zip archive."""
        try:
            with zipfile.ZipFile(kids_path, 'r') as zf:
                # Find the KIDS file inside the zip
                # Prefer files ending in 'k', then any text file
                names = zf.namelist()
                kids_name = None
                for name in names:
                    lower = name.lower()
                    if lower.endswith('k') and not lower.endswith('/'):
                        kids_name = name
                        break
                if not kids_name:
                    # Fall back to first non-directory entry
                    for name in names:
                        if not name.endswith('/'):
                            kids_name = name
                            break
                if not kids_name:
                    print(f"    No files found inside {kids_path}")
                    return None

                raw = zf.read(kids_name)
                try:
                    return raw.decode('utf-8')
                except UnicodeDecodeError:
                    return raw.decode('latin-1')
        except zipfile.BadZipFile:
            print(f"    Bad zip file: {kids_path}")
            return None
        except Exception as e:
            print(f"    Error reading zip {kids_path}: {e}")
            return None

    def _extract_from_kids(self, kids_path, pf):
        """Extract routines and globals from a KIDS file into the Packages/ tree.

        KIDS files contain routines as blocks of text between markers.
        We extract them and write as .m files into the appropriate package dir.

        Returns (routines_count, globals_count)
        """
        routines_extracted = 0
        globals_extracted = 0

        try:
            content = self._read_kids_file(kids_path)
            if content is None:
                return 0, 0
        except Exception as e:
            print(f"    Error reading {kids_path}: {e}")
            return 0, 0

        lines = content.split('\n')

        # Parse routine sections from KIDS
        # KIDS format for routines:
        #   "RTN")
        #   "routinename"
        #   ...
        #   "RTN","routinename",0,0)
        #    header line
        #   "RTN","routinename",0,linenum)
        #    routine line content
        #
        # Actual format varies. Let's use a more robust approach:
        # Look for routine content between "RTN","name",N,0) markers

        routines = self._extract_routines_from_kids(lines)
        globals_data = self._extract_globals_from_kids(lines)

        # Write routines
        for rtn_name, rtn_content in routines.items():
            if not rtn_content.strip():
                continue

            # Sanitize routine name — skip if it contains non-printable chars
            if not rtn_name.isprintable() or '\x00' in rtn_name or '/' in rtn_name:
                print(f"    Skipping routine with invalid name: {rtn_name!r}")
                continue

            # Determine package directory from routine prefix
            pkg_dir = self.mapper.get_routine_dir(rtn_name)
            dest_dir = self.repo_root / pkg_dir
            os.makedirs(dest_dir, exist_ok=True)

            dest_file = dest_dir / f"{rtn_name}.m"
            with open(dest_file, 'w') as f:
                f.write(rtn_content)
                if not rtn_content.endswith('\n'):
                    f.write('\n')
            routines_extracted += 1

        # Write globals
        for gbl_name, gbl_lines in globals_data.items():
            if not gbl_lines:
                continue

            # Clean global name for filename
            clean_name = gbl_name.lstrip('^').replace('(', '+').rstrip(',')
            # Remove any non-printable characters
            clean_name = ''.join(c for c in clean_name if c.isprintable())
            if not clean_name or '/' in clean_name or '\x00' in clean_name:
                print(f"    Skipping global with invalid name: {gbl_name!r}")
                continue

            pkg_dir = self.mapper.get_global_dir(clean_name)
            dest_dir = self.repo_root / pkg_dir
            os.makedirs(dest_dir, exist_ok=True)

            dest_file = dest_dir / f"{clean_name}.zwr"
            # Append to existing or create new
            mode = 'a' if dest_file.exists() else 'w'
            with open(dest_file, mode) as f:
                if mode == 'w':
                    f.write(f"CACHE FORMAT\n")
                    f.write(f"ZWR\n")
                for line in gbl_lines:
                    f.write(line + '\n')
            globals_extracted += 1

        return routines_extracted, globals_extracted

    def _extract_routines_from_kids(self, lines):
        """Extract routines from KIDS build lines.

        KIDS stores routines as pairs of lines:
          "RTN","ROUTINENAME",linenum,0)
          actual line content

        The header "RTN","ROUTINENAME") is followed by a metadata line,
        then the numbered content lines.

        Returns dict of {routinename: content}
        """
        routines = {}
        current_rtn = None
        rtn_lines = {}  # {line_num: content}
        i = 0

        while i < len(lines):
            line = lines[i]

            # Match RTN content lines: "RTN","ROUTINENAME",linenum,0)
            m = re.match(r'^"RTN","([^"]+)",(\d+),0\)$', line)
            if m:
                rtn_name = m.group(1)
                line_num = int(m.group(2))

                if rtn_name != current_rtn:
                    # Save previous routine
                    if current_rtn and rtn_lines:
                        routines[current_rtn] = self._assemble_routine(
                            current_rtn, rtn_lines
                        )
                    current_rtn = rtn_name
                    rtn_lines = {}

                # Content is on the NEXT line
                if line_num > 0 and i + 1 < len(lines):
                    rtn_lines[line_num] = lines[i + 1]
                    i += 2
                    continue

            i += 1

        # Save last routine
        if current_rtn and rtn_lines:
            routines[current_rtn] = self._assemble_routine(
                current_rtn, rtn_lines
            )

        return routines

    def _assemble_routine(self, name, line_dict):
        """Assemble routine content from line number dict."""
        if not line_dict:
            return ''
        max_line = max(line_dict.keys())
        lines = []
        for i in range(1, max_line + 1):
            lines.append(line_dict.get(i, ''))
        return '\n'.join(lines)

    def _extract_globals_from_kids(self, lines):
        """Extract globals from KIDS build file.

        KIDS global data stored as:
        "DATA","globalname",linenum,0) = content

        Or in some formats just raw ZWR lines.

        Returns dict of {global_name: [zwr_lines]}
        """
        globals_data = {}

        for line in lines:
            # Match DATA sections
            m = re.match(r'^"DATA","([^"]+)",.*\)\s*=\s*"(.*)"$', line)
            if m:
                gbl_name = m.group(1)
                content = m.group(2)
                if gbl_name not in globals_data:
                    globals_data[gbl_name] = []
                if content.startswith('^'):
                    globals_data[gbl_name].append(content)
                continue

            # Raw ZWR lines (^GLOBAL(subscript)=value)
            # Must match a valid M global name: ^<ALPHA><ALNUM...>(
            m2 = re.match(r'^(\^[A-Z%][A-Z0-9.]*)\(', line)
            if m2 and '=' in line:
                gbl_name = m2.group(1)
                if gbl_name not in globals_data:
                    globals_data[gbl_name] = []
                globals_data[gbl_name].append(line)

        return globals_data

    def _sha256(self, filepath):
        """Calculate SHA-256 of a file."""
        h = hashlib.sha256()
        with open(filepath, 'rb') as f:
            while True:
                chunk = f.read(8192)
                if not chunk:
                    break
                h.update(chunk)
        return h.hexdigest()

    def _git_commit(self, applied_patches):
        """Commit changes to git."""
        os.chdir(self.repo_root)

        # Stage all Packages/ and Patches/ changes
        subprocess.run(['git', 'add', '--all', 'Packages/'], check=True)
        subprocess.run(['git', 'add', '--all', 'Patches/'], check=True)

        # Check if there are changes
        result = subprocess.run(
            ['git', 'diff', '--cached', '--stat'],
            capture_output=True, text=True
        )
        if not result.stdout.strip():
            print("  No changes to commit.")
            return

        # Build commit message
        patch_ids = sorted(set(pf.patch_id for pf in applied_patches))
        install_names = sorted(set(
            pf.install_name for pf in applied_patches if pf.install_name
        ))

        msg_lines = [
            f"Update from IHS FOIA patches ({datetime.now().strftime('%Y-%m-%d')})",
            "",
            f"Applied {len(patch_ids)} patches from IHS RPMS FTP",
            f"({len(install_names)} with extractable routines/globals):",
            "",
        ]
        for name in install_names[:50]:  # Limit to 50 in message
            msg_lines.append(f"  - {name}")
        if len(install_names) > 50:
            msg_lines.append(f"  ... and {len(install_names) - 50} more")

        commit_msg = '\n'.join(msg_lines)

        subprocess.run(
            ['git', 'commit', '-m', commit_msg],
            check=True
        )
        print(f"  Committed {len(patch_ids)} patches")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Download RPMS patches from IHS and update FOIA-RPMS repo',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              # List available patches (dry run)
              python3 Scripts/update_from_ihs.py --dry-run

              # Download all KIDS patches
              python3 Scripts/update_from_ihs.py --download-only

              # Download, extract, and commit
              python3 Scripts/update_from_ihs.py --commit

              # Re-process previously downloaded patches
              python3 Scripts/update_from_ihs.py --reapply --commit

              # Re-download everything from scratch
              python3 Scripts/update_from_ihs.py --redownload --reapply --commit
        """)
    )
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would be done without making changes')
    parser.add_argument('--download-only', action='store_true',
                        help='Only download files, do not extract or commit')
    parser.add_argument('--commit', action='store_true',
                        help='Commit changes to git after extraction')
    parser.add_argument('--redownload', action='store_true',
                        help='Re-download all files even if already present')
    parser.add_argument('--reapply', action='store_true',
                        help='Re-extract from all downloaded KIDS files')
    parser.add_argument('--force', action='store_true',
                        help='Process unapplied downloads without new files')
    parser.add_argument('--repo-root', default=None,
                        help='Path to FOIA-RPMS repo root (default: auto-detect)')

    args = parser.parse_args()

    # Find repo root
    if args.repo_root:
        repo_root = args.repo_root
    else:
        # Auto-detect: look for Packages.csv
        candidates = ['.', '..']
        repo_root = None
        for c in candidates:
            if os.path.isfile(os.path.join(c, 'Packages.csv')):
                repo_root = c
                break
        if not repo_root:
            print("ERROR: Cannot find FOIA-RPMS repo root (Packages.csv not found).")
            print("       Run from the repo root or use --repo-root=<path>")
            sys.exit(1)

    updater = RPMSUpdater(repo_root, args)
    updater.run()


if __name__ == '__main__':
    main()
