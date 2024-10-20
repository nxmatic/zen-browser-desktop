final: prev: {
  surfer = final.buildNpmPackage {
    pname = "surfer";
    version = "1.5.0";

    src = final.fetchFromGitHub {
      owner = "zen-browser";
      repo = "surfer";
      rev = "50af7094ede6e9f0910f010c531f8447876a6464";
      hash = "sha256-wmAWg6hoICNHfoXJifYFHmyFQS6H22u3GSuRW4alexw=";
    };

    patches = [ ./surfer-dont-check-update.patch ];

    npmDepsHash = "sha256-p0RVqn0Yfe0jxBcBa/hYj5g9XSVMFhnnZT+au+bMs18=";
    makeCacheWritable = true;

    SHARP_IGNORE_GLOBAL_LIBVIPS = false;
    nativeBuildInputs = [ final.pkg-config ];
    buildInputs = [ final.vips ] ++ final.lib.optionals final.stdenv.isDarwin [
      final.darwin.apple_sdk.frameworks.Security
      final.darwin.apple_sdk.frameworks.CoreServices
      final.darwin.apple_sdk.frameworks.CoreFoundation
    ];

    NIX_LDFLAGS = final.lib.optionalString final.stdenv.isDarwin "-framework Security -framework CoreServices -framework CoreFoundation";
  };
}
