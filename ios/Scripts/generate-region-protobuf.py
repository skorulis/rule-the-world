from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "ios/RuleTheWorld/Service/Region/geobuf.pb.swift"


def generate():
    protoc = [shutil.which("protoc")] if shutil.which("protoc") else [sys.executable, "-m", "grpc_tools.protoc"]
    with tempfile.TemporaryDirectory() as temporary:
        subprocess.run([
            *protoc, "-I", str(ROOT / "data/regions"), f"--swift_out={temporary}",
            str(ROOT / "data/regions/geobuf.proto"),
        ], check=True)
        source = (Path(temporary) / "geobuf.pb.swift").read_text()
        source, count = re.subn(
            r"(?m)^([ \t]*)(fileprivate )?(struct|enum|extension) ",
            lambda match: f"{match[1]}{match[2] or ''}nonisolated {match[3]} ",
            source,
        )
        assert count > 0 and "nonisolated struct Geobuf_Data:" in source
        TARGET.write_text(source)


if __name__ == "__main__":
    generate()
