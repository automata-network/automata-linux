class Atakit < Formula
  desc "CLI tool for managing Confidential VMs across AWS, GCP, and Azure"
  homepage "https://github.com/automata-network/automata-linux"
  version "0.1.0"
  license "Apache-2.0"

  depends_on arch: :arm64

  url "https://github.com/automata-network/automata-linux/releases/download/v#{version}/atakit-#{version}-macos-arm64.tar.gz"
  sha256 "e0e6d0e13cc9737a6c46448d35ebf9f52e20aac27bb8495af39b59ca64082860"

  depends_on "jq"
  depends_on "curl"
  depends_on "openssl"
  depends_on "qemu"
  depends_on "python@3.9" => :recommended

  def install
    # Homebrew automatically extracts and cds into the tarball's root directory
    bin.install "bin/atakit"
    (share/"atakit").install Dir["share/atakit/*"]
  end

  test do
    # Test that the binary runs
    system "#{bin}/atakit", "--help" rescue true
    # Syntax validation
    system "bash", "-n", "#{bin}/atakit"
  end

  def caveats
    <<~EOS
      atakit has been installed successfully!

      To use atakit with cloud providers, you need to install their CLIs:
        - AWS:   brew install awscli
        - GCP:   brew install --cask google-cloud-sdk
        - Azure: brew install azure-cli

      User data will be stored in: ~/.atakit/

      Get started:
        atakit --help
    EOS
  end
end
