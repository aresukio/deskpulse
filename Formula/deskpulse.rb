class Deskpulse < Formula
  desc "Work-presence helper agent for macOS"
  homepage "https://github.com/aresukio/homebrew-deskpulse"
  url "https://github.com/aresukio/homebrew-deskpulse/releases/download/39/deskpulse-39-macos-arm64.tar.gz"
  version "39"
  sha256 "a76c488194625a1ff12b0236e28d5c44678f46d6a1bddaa325a3c2f4e037382e"
  license "MIT"

  depends_on :macos

  def install
    bin.install "deskpulse-agent"
    bin.install "deskpulse"
  end

  service do
    run [opt_bin/"deskpulse-agent"]
    keep_alive true
    log_path var/"log/deskpulse-out.txt"
    error_log_path var/"log/deskpulse-err.txt"
    environment_variables(
      DESKPULSE_LAUNCH_LABEL: "homebrew.mxcl.deskpulse",
      DESKPULSE_OUT_LOG_PATH: var/"log/deskpulse-out.txt",
      DESKPULSE_ERR_LOG_PATH: var/"log/deskpulse-err.txt",
    )
  end

  test do
    assert_match "deskpulse - Manage DeskPulse", shell_output("#{bin}/deskpulse help")
  end
end
