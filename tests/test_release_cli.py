import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "release.sh"
BUILD_SCRIPT = ROOT / "build_app.sh"
REBRAND_SCRIPT = ROOT / "scripts" / "rebrand.sh"
BUMP_SCRIPT = ROOT / "scripts" / "bump_version.rb"


def run_release(*args, timeout=20):
    return subprocess.run(
        [str(SCRIPT), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )


def run_build_app(*args, env=None, timeout=20):
    return subprocess.run(
        [str(BUILD_SCRIPT), *args],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )


def run_rebrand(*args, env=None, timeout=20):
    return subprocess.run(
        [str(REBRAND_SCRIPT), *args],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )


def run_bump_version(*args, env=None, input_text="0\n", timeout=20):
    return subprocess.run(
        ["ruby", str(BUMP_SCRIPT), *args],
        cwd=ROOT,
        env=env,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )


class ReleaseCliNonInteractiveTest(unittest.TestCase):
    def test_help_documents_non_interactive_options(self):
        result = run_release("--help")

        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("--action", result.stdout)
        self.assertIn("--dry-run", result.stdout)
        self.assertIn("--non-interactive", result.stdout)

    def test_non_interactive_requires_target_project(self):
        result = run_release("--non-interactive", "--action", "22")

        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Target project wajib diisi", result.stdout)
        self.assertNotIn("Pilihan Anda", result.stdout)

    def test_dry_run_lists_target_type_and_actions_without_executing(self):
        result = run_release(
            "smkgemanusantara",
            "--action",
            "20,22",
            "--app-type",
            "HRM Apps",
            "--dry-run",
        )

        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("DRY RUN", result.stdout)
        self.assertIn("Target project: smkgemanusantara", result.stdout)
        self.assertIn("20: Build APK", result.stdout)
        self.assertIn("22: Build AAB", result.stdout)
        self.assertIn("Tipe : HRM Apps", result.stdout)
        self.assertNotIn("MENJALANKAN OPSI", result.stdout)
        self.assertNotIn("MENGUNGGAH", result.stdout)

    def test_invalid_action_fails_before_execution(self):
        result = run_release("smkgemanusantara", "--action", "99", "--dry-run")

        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Aksi tidak valid: 99", result.stdout)
        self.assertNotIn("Pilihan Anda", result.stdout)
        self.assertNotIn("MENJALANKAN OPSI", result.stdout)

    def test_missing_action_value_fails_without_defaulting_to_release_actions(self):
        result = run_release("smkgemanusantara", "--action")

        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Option --action wajib memiliki nilai", result.stdout)
        self.assertNotIn("MENJALANKAN OPSI", result.stdout)

    def test_invalid_project_fails_in_dry_run(self):
        result = run_release("project-yang-tidak-ada", "--action", "22", "--dry-run")

        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Project 'project-yang-tidak-ada' tidak ditemukan", result.stdout)
        self.assertNotIn("MENJALANKAN OPSI", result.stdout)

    def test_invalid_app_type_fails_in_dry_run(self):
        result = run_release(
            "smkgemanusantara",
            "--action",
            "22",
            "--app-type",
            "Tipe Tidak Ada",
            "--dry-run",
        )

        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Tipe aplikasi 'Tipe Tidak Ada' tidak ditemukan", result.stdout)
        self.assertNotIn("MENJALANKAN OPSI", result.stdout)

    def test_project_creation_dry_run_does_not_prompt_or_write_projects_json(self):
        projects_json = ROOT / "projects.json"
        before = projects_json.read_text()

        result = run_release(
            "--project",
            "Temporary Non Interactive Client",
            "--app-name",
            "Tmp Client",
            "--type",
            "HRM Apps",
            "--base-url",
            "https://example.invalid",
            "--database",
            "tmp_client_db",
            "--dry-run",
        )

        after = projects_json.read_text()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(after, before)
        self.assertIn("DRY RUN", result.stdout)
        self.assertIn("Temporary Non Interactive Client", result.stdout)
        self.assertNotIn("Apakah data di atas sudah benar", result.stdout)

    def test_help_documents_worktree_path_option(self):
        result = run_release("--help")

        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("--worktree-path", result.stdout)

    def test_dry_run_shows_worktree_path_without_writing_config(self):
        config_json = ROOT / "config.json"
        before = config_json.read_text()

        with tempfile.TemporaryDirectory() as tmp_dir:
            result = run_release(
                "smkgemanusantara",
                "--action",
                "22",
                "--app-type",
                "HRM Apps",
                "--worktree-path",
                tmp_dir,
                "--dry-run",
            )

        after = config_json.read_text()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(after, before)
        self.assertIn("Worktree Path", result.stdout)
        self.assertIn("Tidak mengubah config.json", result.stdout)

    def test_worktree_path_requires_app_type(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            result = run_release(
                "smkgemanusantara",
                "--action",
                "22",
                "--worktree-path",
                tmp_dir,
                "--dry-run",
            )

        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("--worktree-path wajib dipakai bersama --app-type", result.stdout)

    def test_worktree_path_must_exist(self):
        missing_path = ROOT / "tmp" / "missing-worktree-path-for-test"
        result = run_release(
            "smkgemanusantara",
            "--action",
            "22",
            "--app-type",
            "HRM Apps",
            "--worktree-path",
            str(missing_path),
            "--dry-run",
        )

        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Worktree path tidak ditemukan", result.stdout)

    def test_build_app_uses_worktree_override_path(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            worktree = tmp_path / "worktree"
            bin_dir = tmp_path / "bin"
            worktree.mkdir()
            bin_dir.mkdir()
            (worktree / "pubspec.yaml").write_text("version: 1.2.3+4\n")
            git_stub = bin_dir / "git"
            git_stub.write_text("#!/bin/sh\nexit 0\n")
            fvm_stub = bin_dir / "fvm"
            fvm_stub.write_text(
                "#!/bin/sh\n"
                "echo \"fvm called from $(pwd)\"\n"
                "mkdir -p build/app/outputs/bundle/release\n"
                "printf aab > build/app/outputs/bundle/release/app-release.aab\n"
                "exit 0\n"
            )
            git_stub.chmod(0o755)
            fvm_stub.chmod(0o755)
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{bin_dir}:{env.get('PATH', '')}",
                    "RELEASE_HUB_WORKTREE_TYPE": "HRM Apps",
                    "RELEASE_HUB_WORKTREE_PATH": str(worktree),
                    "BUILD_TARGET_AAB": "true",
                    "SKIP_UPLOAD": "true",
                }
            )

            result = run_build_app("smkgemanusantara", "HRM Apps", env=env)

        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn(f"Lokasi: {worktree}", result.stdout)
        self.assertIn(f"fvm called from {worktree}", result.stdout)

    def test_rebrand_uses_worktree_override_path(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            worktree = Path(tmp_dir)
            gradle_file = worktree / "android" / "app" / "build.gradle.kts"
            manifest_file = worktree / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
            pbxproj_file = worktree / "ios" / "Runner.xcodeproj" / "project.pbxproj"
            gradle_file.parent.mkdir(parents=True)
            manifest_file.parent.mkdir(parents=True)
            pbxproj_file.parent.mkdir(parents=True)
            gradle_file.write_text('android { namespace = "com.old.app"\n defaultConfig { applicationId = "com.old.app" } }\n')
            manifest_file.write_text('<manifest package="com.old.app" />\n')
            pbxproj_file.write_text('PRODUCT_BUNDLE_IDENTIFIER = com.old.app;\n')
            env = os.environ.copy()
            env["RELEASE_HUB_WORKTREE_PATH"] = str(worktree)

            result = run_rebrand("com.new.app", env=env)

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("Lokasi App", result.stdout)
            self.assertIn(str(worktree), result.stdout)
            self.assertIn("com.new.app", gradle_file.read_text())
            self.assertIn("com.new.app", manifest_file.read_text())
            self.assertIn("com.new.app", pbxproj_file.read_text())

    def test_bump_version_uses_worktree_override_type(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            worktree = Path(tmp_dir)
            pubspec = worktree / "pubspec.yaml"
            pubspec.write_text("name: fake\nversion: 1.2.3+4\n")
            env = os.environ.copy()
            env.update(
                {
                    "RELEASE_HUB_WORKTREE_TYPE": "HRM Apps",
                    "RELEASE_HUB_WORKTREE_PATH": str(worktree),
                }
            )

            result = run_bump_version("smkgemanusantara", "HRM Apps", env=env, input_text="0\n")

        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn(f"Lokasi Project : {worktree}", result.stdout)
        self.assertIn("Versi Saat Ini : 1.2.3+4", result.stdout)


if __name__ == "__main__":
    unittest.main()
