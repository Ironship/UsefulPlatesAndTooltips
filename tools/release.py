"""Prepare, and optionally publish, one release of both packages.

    python tools/release.py --bump             # next patch version in both TOCs
    python tools/release.py                    # build both ZIPs and SHA256SUMS.txt from the TOCs
    python tools/release.py --publish NOTES.md # also create the GitHub release (needs gh)

--bump only edits the two TOC files, so the version change can be committed and merged first.
The build reads the versions back from the TOCs; publishing refuses a dirty working tree or a
branch other than main, so the packages always match what is on GitHub.
"""
import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
dist = root / "dist"
TOCS = ("UsefulPlatesAndTooltips.toc", "UsefulPlatesAndTooltips_Mainline.toc")
VERSION = re.compile(r"^(## Version:\s*)(\d+)\.(\d+)\.(\d+)(\S*)", re.M)


def version(toc):
    m = VERSION.search((root / toc).read_text(encoding="utf-8"))
    if not m:
        sys.exit(f"no version in {toc}")
    return f"{m.group(2)}.{m.group(3)}.{m.group(4)}{m.group(5)}"


def bump(toc):
    path = root / toc
    text = path.read_bytes().decode("utf-8")
    new = VERSION.sub(lambda m: f"{m.group(1)}{m.group(2)}.{m.group(3)}.{int(m.group(4)) + 1}{m.group(5)}", text, count=1)
    if new == text:
        sys.exit(f"no version in {toc}")
    path.write_bytes(new.encode("utf-8"))
    print(f"{toc}: {version(toc)}")


def run(*cmd):
    result = subprocess.run(cmd, cwd=root, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"{' '.join(cmd)} failed:\n{result.stdout}{result.stderr}")
    return result.stdout.strip()


parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument("--bump", action="store_true", help="raise the patch version in both TOCs and stop")
parser.add_argument("--publish", metavar="NOTES", help="create the GitHub release with this notes file")
parser.add_argument("--title", help="release title (default: the two versions)")
args = parser.parse_args()

if args.bump:
    for toc in TOCS:
        bump(toc)
    sys.exit(0)

forever, retail = version(TOCS[0]), version(TOCS[1])
if args.publish:
    if run("git", "status", "--porcelain"):
        sys.exit("the working tree has uncommitted changes")
    if run("git", "branch", "--show-current") != "main":
        sys.exit("publish from main")

for flags in ([], ["--retail"]):
    print(run(sys.executable, str(root / "tools" / "build_zip.py"), *flags))

zips = [dist / f"UsefulPlatesAndTooltips-{v}.zip" for v in (forever, retail)]
sums = dist / "SHA256SUMS.txt"
sums.write_text("".join(f"{hashlib.sha256(z.read_bytes()).hexdigest()}  {z.name}\n" for z in zips),
                encoding="utf-8", newline="\n")
print(sums.read_text(encoding="utf-8"), end="")

if args.publish:
    title = args.title or f"Forever {forever} / Retail {retail.replace('-retail', '')}"
    print(run("gh", "release", "create", f"v{forever}", *(str(z) for z in zips), str(sums),
              "--title", title, "--notes-file", args.publish, "--target", "main"))
