import os
import subprocess
import sys
import tempfile

def run_command(command):
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
        return output.decode().strip()
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Ausführen von {command}: {e.output.decode().strip()}")
        sys.exit(e.returncode)

def main():
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Verwendung: cargo2deb.py <package> [prefix]")
        sys.exit(1)

    package = sys.argv[1]
    prefix = '/usr/local' if len(sys.argv) == 2 else sys.argv[2]

    # Abhängigkeiten prüfen
    dependencies = ["cargo"]
    for dep in dependencies:
        if not shutil.which(dep):
            print(f"Abhängigkeit nicht gefunden: {dep}")
            sys.exit(1)

    # Temporäres Verzeichnis erstellen
    tempdir = tempfile.mkdtemp()
    print(f"Temporäres Verzeichnis erstellt: {tempdir}")

    # Installiere Cargo Binary in das Debian-Paket
    builddir = os.path.join(tempdir, f"{package}{prefix}")
    os.makedirs(builddir, exist_ok=True)
    run_command(f"cargo install {package} --root {builddir}")

    # Metadaten extrahieren
    metadata_output = run_command(f"cargo search {package}")
    version = next(line for line in metadata_output.split('\n') if line.startswith(package)).split('"')[1]
    description = ' '.join(metadata_output.split('"')[2].strip().split()[1:])

    # Control-Datei schreiben
    debian_dir = os.path.join(tempdir, package, "DEBIAN")
    os.makedirs(debian_dir, exist_ok=True)
    arch = run_command("dpkg --print-architecture")
    control_file_path = os.path.join(debian_dir, "control")
    with open(control_file_path, 'w') as control_file:
        control_file.write(
            f"Package: rust-{package}\n"
            f"Version: {version}\n"
            f"Section: utils\n"
            f"Priority: optional\n"
            f"Architecture: {arch}\n"
            f"Maintainer: cargo2deb <info@cargo2deb.org>\n"
            f"Description: {description}\n"
        )

    # Debian-Paket erstellen
    os.chdir(tempdir)
    run_command(f"tar -cJf data.tar.xz ./{package}")
    run_command(f"tar -cJf control.tar.xz ./DEBIAN")
    run_command("echo 2.0 > debian-binary")
    package_name = f"{package}_{version}_{arch}.deb"
    run_command(f"ar rcs {package_name} debian-binary control.tar.xz data.tar.xz")

    # Aufräumen
    os.rename(os.path.join(tempdir, package_name), os.path.join(os.getcwd(), package_name))
    shutil.rmtree(tempdir)
    print(f"Debian-Paket erfolgreich erstellt: {package_name}")

if __name__ == "__main__":
    main()