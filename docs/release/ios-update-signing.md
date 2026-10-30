# In-place iOS update signing

For an update intended to preserve an existing Wallet, select the exact previously
installed signed package from the device's recorded bundle version. Pass it as
`--baseline-app` to `scripts/package-ios-app.py`, together with the ordinary
source/output/build/identity arguments. The guard verifies the baseline signature,
requires identical bundle identity and entitlements, and checks that the current
profile admits its Keychain groups before creating or signing an output.

Profile renewal is permitted; changing capabilities or Keychain groups requires
separate review. Omitting `--baseline-app` compares only with the source build,
which is insufficient evidence of compatibility with an installed app.

Before installation, verify the packaged output again with `--verify-only` and
`--baseline-app`. Gate installation on successful checks using checked subprocess
calls; never put an install command after a newline and assume a prior failure
stops the shell. Install in place, verify the device bundle version, and leave
Wallet unlock/consent to the person. Never uninstall as an update workaround.

Regression tests: `python3 -m unittest discover -s scripts -p 'test_package_ios_app.py'`.
