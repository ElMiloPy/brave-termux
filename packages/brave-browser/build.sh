TERMUX_PKG_HOMEPAGE=https://brave.com/
TERMUX_PKG_DESCRIPTION="Brave web browser"
TERMUX_PKG_LICENSE="BSD 3-Clause, MPL-2.0"
TERMUX_PKG_MAINTAINER="@ElMiloPy"
TERMUX_PKG_VERSION=149.0.7827.155
TERMUX_PKG_REVISION=1
BRAVE_CORE_VERSION="v1.91.177"
BRAVE_CORE_SHA256="ee0d0885ff9fdbbabce298becfb23714da05783533646c350c600b38129ba122"
TERMUX_PKG_SRCURL="https://commondatastorage.googleapis.com/chromium-browser-official/chromium-$TERMUX_PKG_VERSION-lite.tar.xz"
TERMUX_PKG_SHA256=4e39fd0ae3ad64fd4bff6a523d94fe5e2917ad51a7f46a73c84a5736d9dda862
TERMUX_PKG_DEPENDS="atk, cups, dbus, fontconfig, gtk3, krb5, libc++, libevdev, libxkbcommon, libminizip, libnss, libx11, mesa, openssl, pango, pipewire, pulseaudio, zlib"
TERMUX_PKG_BUILD_DEPENDS="brave-host-tools, libffi-static"
# TODO: Split chromium-common and chromium-headless
# TERMUX_PKG_DEPENDS+=", chromium-common"
# TERMUX_PKG_SUGGESTS="chromium-headless, chromium-driver"
# Chromium doesn't support i686 on Linux.
TERMUX_PKG_EXCLUDED_ARCHES="i686"
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_ON_DEVICE_BUILD_NOT_SUPPORTED=true

SYSTEM_LIBRARIES="    fontconfig"
# TERMUX_PKG_DEPENDS="fontconfig"

termux_step_post_get_source() {
	# Version guard
	local version_tools=$(. $TERMUX_SCRIPTDIR/x11-packages/brave-host-tools/build.sh; echo ${TERMUX_PKG_VERSION})
	if [ "${version_tools}" != "${TERMUX_PKG_VERSION}" ]; then
		termux_error_exit "Version mismatch between brave-host-tools and brave-browser."
	fi

	# Fetch brave-core source into src/brave
	local _brave_tarball="$TERMUX_PKG_CACHEDIR/brave-core-${BRAVE_CORE_VERSION}.tar.gz"
	termux_download \
		"https://codeload.github.com/brave/brave-core/legacy.tar.gz/refs/tags/${BRAVE_CORE_VERSION}" \
		"${_brave_tarball}" \
		"${BRAVE_CORE_SHA256}"
	rm -rf "$TERMUX_PKG_SRCDIR/brave"
	mkdir -p "$TERMUX_PKG_SRCDIR/brave"
	tar -xzf "${_brave_tarball}" --strip-components=1 -C "$TERMUX_PKG_SRCDIR/brave"
	touch "$TERMUX_PKG_SRCDIR/brave/.env"

	# Clone minimal submodules required by brave_sync and build
	if [ ! -d "$TERMUX_PKG_SRCDIR/brave/third_party/bip39wally-core-native" ]; then
		git clone --depth 1 https://github.com/brave-intl/bat-native-bip39wally-core.git \
			"$TERMUX_PKG_SRCDIR/brave/third_party/bip39wally-core-native"
	fi
	if [ ! -d "$TERMUX_PKG_SRCDIR/brave/vendor/bat-native-tweetnacl" ]; then
		git clone --depth 1 https://github.com/brave-intl/bat-native-tweetnacl.git \
			"$TERMUX_PKG_SRCDIR/brave/vendor/bat-native-tweetnacl"
	fi
	if [ ! -d "$TERMUX_PKG_SRCDIR/brave/vendor/web-discovery-project" ]; then
		git clone https://github.com/brave/web-discovery-project.git \
			"$TERMUX_PKG_SRCDIR/brave/vendor/web-discovery-project"
		pushd "$TERMUX_PKG_SRCDIR/brave/vendor/web-discovery-project"
		git checkout f25eb3d6f91f5618c04894db98f8d65bab8301d1
		popd
	fi
	if [ ! -d "$TERMUX_PKG_SRCDIR/brave/node_modules/@brave/leo/tokens/skia" ]; then
		mkdir -p "$TERMUX_PKG_SRCDIR/brave/node_modules/@brave"
		[ -d "$TERMUX_PKG_SRCDIR/brave/node_modules/@brave/leo" ] || git clone https://github.com/brave/leo.git \
			"$TERMUX_PKG_SRCDIR/brave/node_modules/@brave/leo"
		pushd "$TERMUX_PKG_SRCDIR/brave/node_modules/@brave/leo"
		git checkout 075a3f9ed76e03bdc3f63d7dc4a7269e6dbdec29
		git config --global url."https://github.com/".insteadOf "git@github.com:"
		git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
		npm install
		npm run transform-tokens
		npm run skiafy-icons
		popd
	fi
	_clone_brave_dep() {
		local dir="$TERMUX_PKG_SRCDIR/brave/$1"
		local url="$2"
		local commit="$3"
		if [ ! -d "$dir" ]; then
			mkdir -p "$(dirname "$dir")"
			git clone "$url" "$dir" && (cd "$dir" && git checkout "$commit")
		fi
	}
	_clone_brave_dep "third_party/ethash/src" "https://github.com/chfast/ethash.git" "e4a15c3d76dc09392c7efd3e30d84ee3b871e9ce"
	_clone_brave_dep "third_party/bitcoin-core/src" "https://github.com/bitcoin/bitcoin.git" "8105bce5b384c72cf08b25b7c5343622754e7337"
	_clone_brave_dep "third_party/argon2/src" "https://github.com/P-H-C/phc-winner-argon2.git" "62358ba2123abd17fccf2a108a301d4b52c01a7c"
	_clone_brave_dep "third_party/playlist_component/src" "https://github.com/brave/playlist-component.git" "673d40f017a1559bb685a15cf608ad1d4a94f8fb"
	_clone_brave_dep "third_party/rust/futures_retry/v0_5/crate" "https://github.com/brave-intl/futures-retry.git" "2aaaafbc3d394661534d4dbd14159d164243c20e"
	_clone_brave_dep "components/brave_wallet/browser/zcash/rust/librustzcash/src" "https://github.com/brave/librustzcash.git" "f34cb36d9287b76b52ba1a2ab58e50db96706dc8"

	if [ ! -d "$TERMUX_PKG_SRCDIR/brave/components/brave_extension/extension/brave_extension/_locales/ar_XB" ]; then
		cp -rf "$TERMUX_PKG_SRCDIR/brave/components/brave_extension/extension/brave_extension/_locales/ar" \
			"$TERMUX_PKG_SRCDIR/brave/components/brave_extension/extension/brave_extension/_locales/ar_XB"
		cp -rf "$TERMUX_PKG_SRCDIR/brave/components/brave_extension/extension/brave_extension/_locales/en_US" \
			"$TERMUX_PKG_SRCDIR/brave/components/brave_extension/extension/brave_extension/_locales/en_XA"
	fi

	# Apply brave-core patches
	python3 "$TERMUX_PKG_BUILDER_DIR/scripts/apply_brave_patches.py" "$TERMUX_PKG_SRCDIR"

	# Apply patches related to chromium
	local f
	for f in $(find "$TERMUX_PKG_BUILDER_DIR/../brave-host-tools/cr-patches" -maxdepth 1 -type f -name *.patch | sort); do
		echo "Applying patch: $(basename $f)"
		patch -p1 --silent < "$f"
	done

	# Enable jumbo build for //components and //chrome
	python \
		"$TERMUX_PKG_BUILDER_DIR/../brave-host-tools/scripts/rewrite_gn_jumbo.py" \
		"$TERMUX_PKG_SRCDIR" \
		--verbose \
		--subdirs chrome \
		--subdirs components

	# Apply patches for jumbo build
	local f
	for f in $(find "$TERMUX_PKG_BUILDER_DIR/../brave-host-tools/jumbo-patches" -maxdepth 1 -type f -name *.patch | sort); do
		echo "Applying patch: $(basename $f)"
		patch -p1 --silent < "$f"
	done

	# Use some system libs
	python3 build/linux/unbundle/replace_gn_files.py --system-libraries \
		$SYSTEM_LIBRARIES

	# Remove the source file to keep more space
	rm -f "$TERMUX_PKG_CACHEDIR/chromium-$TERMUX_PKG_VERSION-lite.tar.xz"
}

termux_step_pre_configure() {
	# Fix Brave chromium_src override resolution when builddir is outside src
	sed -i "s/assert not src_path.startswith('\.\.'), (path, src_dir)/if src_path.startswith('..'): return ''/g" "$TERMUX_PKG_SRCDIR/brave/script/brave_chromium_utils.py"

	# Run Brave branding update to copy branded strings, icons, and localized grd files
	if [ -f "$TERMUX_PKG_SRCDIR/brave/build/commands/lib/branding.js" ]; then
		(cd "$TERMUX_PKG_SRCDIR/brave" && npx tsx -e '
import branding from "./build/commands/lib/branding.js";
branding.update();
')
	fi

	# Fix pkg-config prepending sysroot to root include dir, shadowing libc++ headers
	sed -i 's|elif flag\[:2\] == '\''-I'\'':|elif flag[:2] == '\''-I'\'':\n      if flag[2:].rstrip("/").endswith("/usr/include") or flag[2:].rstrip("/") == "/usr/include": continue|g' "$TERMUX_PKG_SRCDIR/build/config/linux/pkg-config.py"

	# Teach merge_for_jumbo.py to include Brave chromium_src overrides when available
	python3 -c '
file_path = "'"$TERMUX_PKG_SRCDIR"'/build/config/merge_for_jumbo.py"
with open(file_path, "r") as f: content = f.read()
target = "      out.write(\"#include \\\"%s\\\"\\n\" % filename)\n      written_input_set.add(filename)"
replacement = """      orig_filename = filename
      if "src/" in filename:
        override = filename.replace("src/", "src/brave/chromium_src/", 1)
        if os.path.exists(override): filename = override
      elif filename.startswith("../../"):
        override = "../../brave/chromium_src/" + filename[6:]
        if os.path.exists(override): filename = override
      out.write("#include \\"%s\\"\\n" % filename)
      written_input_set.add(orig_filename)"""
if target in content:
    with open(file_path, "w") as f: f.write(content.replace(target, replacement, 1))
'

	# Fix jumbo symbol collision in SOCKS5ClientSocket
	if [ -f "$TERMUX_PKG_SRCDIR/brave/chromium_src/net/socket/socks5_client_socket.cc" ]; then
		sed -i 's/ToLegacyDestinationEndpoint/Socks5ToLegacyDestinationEndpoint/g' "$TERMUX_PKG_SRCDIR/brave/chromium_src/net/socket/socks5_client_socket.cc"
	fi

	# Fix missing <iostream> in ANGLE files
	for _f in \
		"third_party/angle/src/compiler/translator/wgsl/RewritePipelineVariables.cpp" \
		"third_party/angle/src/libANGLE/renderer/wgpu/ProgramWgpu.cpp" \
		"third_party/angle/src/libANGLE/renderer/wgpu/wgpu_wgsl_util.cpp" \
		"third_party/angle/src/libANGLE/renderer/vulkan/CLContextVk.cpp"; do
		if [ -f "$TERMUX_PKG_SRCDIR/$_f" ]; then
			grep -q "<iostream>" "$TERMUX_PKG_SRCDIR/$_f" || sed -i '1s/^/#include <iostream>\n/' "$TERMUX_PKG_SRCDIR/$_f"
		fi
	done

	# Fix OVERRIDE_FEATURE_DEFAULT_STATES symbol collision in jumbo builds
	if [ -f "$TERMUX_PKG_SRCDIR/brave/chromium_src/base/feature_override.h" ]; then
		python3 -c '
file_path = "'"$TERMUX_PKG_SRCDIR"'/brave/chromium_src/base/feature_override.h"
with open(file_path, "r") as f: c = f.read()
if "BRAVE_CONCAT" not in c:
    c = c.replace("#define OVERRIDE_FEATURE_DEFAULT_STATES(...) \\", """#define BRAVE_CONCAT_INTERNAL(a, b) a##b
#define BRAVE_CONCAT(a, b) BRAVE_CONCAT_INTERNAL(a, b)

#define OVERRIDE_FEATURE_DEFAULT_STATES(...) \\""")
    c = c.replace("g_feature_default_state_overrider __VA_ARGS__;", "BRAVE_CONCAT(g_feature_default_state_overrider_, __COUNTER__) __VA_ARGS__;")
    with open(file_path, "w") as f: f.write(c)
'
	fi

	# Fix un-restored BUILDFLAG_INTERNAL_GOOGLE_CHROME_BRANDING breaking subsequent jumbo files
	python3 -c '
import glob, os
for root, _, files in os.walk("'"$TERMUX_PKG_SRCDIR"'/brave/chromium_src"):
    for fname in files:
        if fname.endswith((".cc", ".h", ".mm")):
            fpath = os.path.join(root, fname)
            with open(fpath, "r", errors="ignore") as f: content = f.read()
            if "#undef BUILDFLAG_INTERNAL_GOOGLE_CHROME_BRANDING" in content:
                lines = content.splitlines(keepends=True)
                new_lines = []
                modified = False
                for i, line in enumerate(lines):
                    new_lines.append(line)
                    if line.strip() == "#undef BUILDFLAG_INTERNAL_GOOGLE_CHROME_BRANDING":
                        has_restore = any("define BUILDFLAG_INTERNAL_GOOGLE_CHROME_BRANDING" in lines[j] for j in range(i + 1, min(i + 4, len(lines))))
                        if not has_restore:
                            new_lines.append("#define BUILDFLAG_INTERNAL_GOOGLE_CHROME_BRANDING() (0)\n")
                            modified = True
                if modified:
                    with open(fpath, "w") as f: f.writelines(new_lines)
'

	# Un-jumbo targets that conflict with Brave macro class aliases
	for _f in \
		"components/sync/engine/BUILD.gn" \
		"components/sync/service/BUILD.gn" \
		"components/browser_sync/BUILD.gn" \
		"components/send_tab_to_self/BUILD.gn"; do
		if [ -f "$TERMUX_PKG_SRCDIR/$_f" ]; then
			sed -i '/import("\/\/build\/config\/jumbo.gni")/d' "$TERMUX_PKG_SRCDIR/$_f"
			sed -i 's/jumbo_static_library/static_library/g' "$TERMUX_PKG_SRCDIR/$_f"
			sed -i 's/jumbo_source_set/source_set/g' "$TERMUX_PKG_SRCDIR/$_f"
			sed -i 's/jumbo_component/component/g' "$TERMUX_PKG_SRCDIR/$_f"
		fi
	done

	# Exclude web_contents_impl.cc from jumbo in content/browser
	if [ -f "$TERMUX_PKG_SRCDIR/content/browser/BUILD.gn" ]; then
		grep -q "web_contents/web_contents_impl.cc" "$TERMUX_PKG_SRCDIR/content/browser/BUILD.gn" || \
			sed -i '/"webid\/document_metadata.cc",/a \    "web_contents/web_contents_impl.cc",' "$TERMUX_PKG_SRCDIR/content/browser/BUILD.gn"
	fi

	# Exclude overridden generated files from jumbo in blink modules bindings
	if [ -f "$TERMUX_PKG_SRCDIR/third_party/blink/renderer/bindings/modules/v8/BUILD.gn" ]; then
		grep -q "v8_storage_estimate.cc" "$TERMUX_PKG_SRCDIR/third_party/blink/renderer/bindings/modules/v8/BUILD.gn" || \
			sed -i '/deps = \[/i \  jumbo_excluded_sources = [\n    "$root_gen_dir/third_party/blink/renderer/bindings/modules/v8/v8_navigator.cc",\n    "$root_gen_dir/third_party/blink/renderer/bindings/modules/v8/v8_storage_estimate.cc",\n    "$root_gen_dir/third_party/blink/renderer/bindings/modules/v8/v8_worker_navigator.cc",\n  ]\n' "$TERMUX_PKG_SRCDIR/third_party/blink/renderer/bindings/modules/v8/BUILD.gn"
	fi

	# Fix jumbo is_android redefinition in components/omnibox/browser
	python3 -c '
def patch_file(path, macro_name):
    try:
        with open(path, "r") as f: content = f.read()
    except Exception: return
    if f"#define is_android {macro_name}" in content: return
    target = "constexpr bool is_android = !!BUILDFLAG(IS_ANDROID);"
    if target not in content: return
    content = content.replace(target, f"#define is_android {macro_name}\n" + target, 1)
    content = content + f"\n#undef is_android\n"
    with open(path, "w") as f: f.write(content)

base = "'"$TERMUX_PKG_SRCDIR"'/components/omnibox/browser"
patch_file(f"{base}/clipboard_provider.cc", "is_android_clipboard_provider")
patch_file(f"{base}/zero_suggest_verbatim_match_provider.cc", "is_android_zero_suggest_verbatim_match_provider")
patch_file(f"{base}/autocomplete_controller.cc", "is_android_autocomplete_controller")
'

	# Fix Brave GetVectorIcon macro collision with OmniboxAction in autocomplete_match.cc
	if [ -f "$TERMUX_PKG_SRCDIR/components/omnibox/browser/autocomplete_match.cc" ]; then
		python3 -c '
path = "'"$TERMUX_PKG_SRCDIR"'/components/omnibox/browser/autocomplete_match.cc"
with open(path, "r") as f: c = f.read()
target = """    case Type::PEDAL:
      return takeover_action ? takeover_action->GetVectorIcon()
                             : vector_icons::kSearchChromeRefreshIcon;"""
replacement = """    case Type::PEDAL:
#pragma push_macro("GetVectorIcon")
#undef GetVectorIcon
      return takeover_action ? takeover_action->GetVectorIcon()
                             : vector_icons::kSearchChromeRefreshIcon;
#pragma pop_macro("GetVectorIcon")"""
if target in c:
    with open(path, "w") as f: f.write(c.replace(target, replacement, 1))
'
	fi

	# Fix missing TypeScript type for window.testing in brave_tor_subpage.ts
	if [ -f "$TERMUX_PKG_SRCDIR/brave/browser/resources/settings/brave_tor_page/brave_tor_subpage.ts" ]; then
		sed -i 's/window\.testing = window\.testing/const win = window as any;\n      win.testing = win.testing/g' "$TERMUX_PKG_SRCDIR/brave/browser/resources/settings/brave_tor_page/brave_tor_subpage.ts"
		sed -i 's/window\.testing\.torSubpage/win.testing.torSubpage/g' "$TERMUX_PKG_SRCDIR/brave/browser/resources/settings/brave_tor_page/brave_tor_subpage.ts"
	fi

	# Fix incomplete OnceCallback type instantiation in tor_control.h with LLVM libc++ 21
	if [ -f "$TERMUX_PKG_SRCDIR/brave/components/tor/tor_control.h" ]; then
		sed -i 's|"base/functional/callback_forward.h"|"base/functional/callback.h"|g' "$TERMUX_PKG_SRCDIR/brave/components/tor/tor_control.h"
	fi

	# Fix undefined IDS_CHROME_SHORTCUT_NAME_BETA/DEV in welcome_dom_handler.cc
	if [ -f "$TERMUX_PKG_SRCDIR/brave/browser/ui/webui/welcome_page/welcome_dom_handler.cc" ]; then
		sed -i 's/l10n_util::GetStringUTF16(IDS_CHROME_SHORTCUT_NAME_BETA)/u"Google Chrome Beta"/g' "$TERMUX_PKG_SRCDIR/brave/browser/ui/webui/welcome_page/welcome_dom_handler.cc"
		sed -i 's/l10n_util::GetStringUTF16(IDS_CHROME_SHORTCUT_NAME_DEV)/u"Google Chrome Dev"/g' "$TERMUX_PKG_SRCDIR/brave/browser/ui/webui/welcome_page/welcome_dom_handler.cc"
	fi

	# Make TabHelpers::AttachTabHelpers public so desktop BrowserTabStripModelDelegate can access it on Android
	if [ -f "$TERMUX_PKG_SRCDIR/chrome/browser/ui/tab_helpers.h" ]; then
		sed -i 's/static void AttachTabHelpers(content::WebContents\* web_contents);/public:\n  static void AttachTabHelpers(content::WebContents* web_contents);/g' "$TERMUX_PKG_SRCDIR/chrome/browser/ui/tab_helpers.h"
	fi

	# Fix jumbo symbol collision for ToolbarButtonHighlightPathGenerator in brave toolbar_ink_drop_util.cc
	if [ -f "$TERMUX_PKG_SRCDIR/brave/chromium_src/chrome/browser/ui/views/toolbar/toolbar_ink_drop_util.cc" ]; then
		grep -q "ToolbarButtonHighlightPathGenerator_DropUtil" "$TERMUX_PKG_SRCDIR/brave/chromium_src/chrome/browser/ui/views/toolbar/toolbar_ink_drop_util.cc" || \
			sed -i 's/#undef ConfigureInkDropForToolbar/#undef ConfigureInkDropForToolbar\n\n#define ToolbarButtonHighlightPathGenerator ToolbarButtonHighlightPathGenerator_DropUtil/g' "$TERMUX_PKG_SRCDIR/brave/chromium_src/chrome/browser/ui/views/toolbar/toolbar_ink_drop_util.cc"
	fi

	# Fix missing vector_icons.h in brave extensions_menu_entry_view.cc
	if [ -f "$TERMUX_PKG_SRCDIR/brave/chromium_src/chrome/browser/ui/views/extensions/extensions_menu_entry_view.cc" ]; then
		grep -q "brave/components/vector_icons/vector_icons.h" "$TERMUX_PKG_SRCDIR/brave/chromium_src/chrome/browser/ui/views/extensions/extensions_menu_entry_view.cc" || \
			sed -i '/extensions_menu_entry_view.h"/a #include "brave/components/vector_icons/vector_icons.h"' "$TERMUX_PKG_SRCDIR/brave/chromium_src/chrome/browser/ui/views/extensions/extensions_menu_entry_view.cc"
	fi

	# Fix non-widevine AddAdditionalWidevineViewControlsIfNeeded signature in permission_prompt_bubble_base_view.cc
	if [ -f "$TERMUX_PKG_SRCDIR/brave/chromium_src/chrome/browser/ui/views/permissions/permission_prompt_bubble_base_view.cc" ]; then
		python3 -c '
path = "'"$TERMUX_PKG_SRCDIR"'/brave/chromium_src/chrome/browser/ui/views/permissions/permission_prompt_bubble_base_view.cc"
with open(path, "r") as f: c = f.read()
target = """#else
void AddAdditionalWidevineViewControlsIfNeeded(
    views::BubbleDialogDelegateView* dialog_delegate_view,
    const std::vector<raw_ptr<permissions::PermissionRequest,
                              VectorExperimental>>& requests) {}
#endif"""
replacement = """#else
template <typename T>
void AddAdditionalWidevineViewControlsIfNeeded(
    views::BubbleDialogDelegateView* dialog_delegate_view,
    const T& requests) {}
#endif"""
if target in c:
    with open(path, "w") as f: f.write(c.replace(target, replacement, 1))
'
	fi

	# Fix BubbleDialogDelegateView constructors accessibility for Brave subclasses in jumbo builds
	if [ -f "$TERMUX_PKG_SRCDIR/ui/views/bubble/bubble_dialog_delegate_view.h" ]; then
		python3 -c '
path = "'"$TERMUX_PKG_SRCDIR"'/ui/views/bubble/bubble_dialog_delegate_view.h"
with open(path, "r") as f: c = f.read()
target = """  // |shadow| usually doesn'\''t need to be explicitly set, just uses the default
  // argument. Unless on Mac when the bubble needs to use Views base shadow,
  // override it with suitable bubble border type.
  explicit BubbleDialogDelegateView("""
replacement = """  // |shadow| usually doesn'\''t need to be explicitly set, just uses the default
  // argument. Unless on Mac when the bubble needs to use Views base shadow,
  // override it with suitable bubble border type.
 protected:
  explicit BubbleDialogDelegateView("""
if target in c:
    c = c.replace(target, replacement, 1)
    target2 = """: BubbleDialogDelegateView(BubbleAnchor(anchor_view),
                                 arrow,
                                 shadow,
                                 autosize) {}

  static BddvPassKey CreatePassKey() { return BddvPassKey(); }"""
    replacement2 = """: BubbleDialogDelegateView(BubbleAnchor(anchor_view),
                                 arrow,
                                 shadow,
                                 autosize) {}

 private:
  static BddvPassKey CreatePassKey() { return BddvPassKey(); }"""
    if target2 in c:
        c = c.replace(target2, replacement2, 1)
        with open(path, "w") as f: f.write(c)
'
	fi

	# Fix jumbo symbol collision for IsFrameWithOpaqueOrigin in brave_content_settings_agent_impl.cc
	if [ -f "$TERMUX_PKG_SRCDIR/brave/components/content_settings/renderer/brave_content_settings_agent_impl.cc" ]; then
		sed -i 's/bool IsFrameWithOpaqueOrigin(/bool BraveIsFrameWithOpaqueOrigin(/g; s/IsFrameWithOpaqueOrigin(frame)/BraveIsFrameWithOpaqueOrigin(frame)/g' "$TERMUX_PKG_SRCDIR/brave/components/content_settings/renderer/brave_content_settings_agent_impl.cc"
	fi

	# Fix ChromeMetricsServiceAccessor friends/visibility for Brave ChromiumImpl classes in jumbo builds
	if [ -f "$TERMUX_PKG_SRCDIR/chrome/browser/metrics/chrome_metrics_service_accessor.h" ]; then
		sed -i 's/friend class ChromeBrowserMainParts;/friend class ChromeBrowserMainParts;\n  friend class ChromeBrowserMainParts_ChromiumImpl;/g' "$TERMUX_PKG_SRCDIR/chrome/browser/metrics/chrome_metrics_service_accessor.h"
		sed -i 's/friend class ChromeMetricsServiceClient;/friend class ChromeMetricsServiceClient;\n  friend class ChromeMetricsServiceClient_ChromiumImpl;/g' "$TERMUX_PKG_SRCDIR/chrome/browser/metrics/chrome_metrics_service_accessor.h"
		sed -i 's/static bool RegisterSyntheticFieldTrial(/public:\n  static bool RegisterSyntheticFieldTrial(/g' "$TERMUX_PKG_SRCDIR/chrome/browser/metrics/chrome_metrics_service_accessor.h"
	fi

	# Fix SetDownloadDisplayController type mismatch in jumbo builds
	if [ -f "$TERMUX_PKG_SRCDIR/chrome/browser/download/bubble/download_bubble_ui_controller.h" ]; then
		python3 -c '
path = "'"$TERMUX_PKG_SRCDIR"'/chrome/browser/download/bubble/download_bubble_ui_controller.h"
with open(path, "r") as f: c = f.read()
target = """  void SetDownloadDisplayController(DownloadDisplayController* controller) {
    display_controller_ = controller;
  }"""
replacement = """  template <typename T = DownloadDisplayController>
  void SetDownloadDisplayController(T* controller) {
    display_controller_ = reinterpret_cast<DownloadDisplayController*>(controller);
  }"""
if target in c:
    with open(path, "w") as f: f.write(c.replace(target, replacement, 1))
'
	fi

	# Exclude overridden generated files from jumbo in third_party/blink/common/BUILD.gn
	if [ -f "$TERMUX_PKG_SRCDIR/third_party/blink/common/BUILD.gn" ]; then
		grep -q "origin_trials.cc" "$TERMUX_PKG_SRCDIR/third_party/blink/common/BUILD.gn" || \
			sed -i '/configs += \[ ":blink_common_implementation" \]/a \  jumbo_excluded_sources = [\n    "$root_gen_dir/third_party/blink/common/features_generated.cc",\n    "$root_gen_dir/third_party/blink/common/origin_trials/origin_trials.cc",\n  ]' "$TERMUX_PKG_SRCDIR/third_party/blink/common/BUILD.gn"
	fi

	# Fix feature_compiler.py path resolution when build dir is outside src
	if [ -f "$TERMUX_PKG_SRCDIR/brave/chromium_src/tools/json_schema_compiler/feature_compiler.py" ]; then
		python3 -c '
file_path = "'"$TERMUX_PKG_SRCDIR"'/brave/chromium_src/tools/json_schema_compiler/feature_compiler.py"
with open(file_path, "r") as f: c = f.read()
target = """    parent_dir_prefix = "../../"
    feature_replace_prefix = "replace!"

    for source_file in self._source_files:
        assert source_file.startswith(parent_dir_prefix), source_file
        source_file = source_file[len(parent_dir_prefix):]"""
replacement = """    feature_replace_prefix = "replace!"
    src_root = brave_chromium_utils.wspath("//")

    for source_file in self._source_files:
        source_file = os.path.relpath(os.path.abspath(source_file), src_root)"""
if target in c:
    with open(file_path, "w") as f: f.write(c.replace(target, replacement, 1))
'
	fi

	# Fix switches::kComponentUpdater namespace lookup in brave_extensions_client.cc in jumbo
	if [ -f "$TERMUX_PKG_SRCDIR/brave/common/extensions/brave_extensions_client.cc" ]; then
		sed -i 's/switches::kComponentUpdater/::switches::kComponentUpdater/g' "$TERMUX_PKG_SRCDIR/brave/common/extensions/brave_extensions_client.cc"
	fi

	# Fix libc++ 21 optional::value_or({}) template deduction in brave sources
	if [ -f "$TERMUX_PKG_SRCDIR/brave/components/brave_ads/core/internal/legacy_migration/confirmations/legacy_confirmation_migration.cc" ]; then
		sed -i 's/ParseConfirmationTokens(\*json, \*wallet)\.value_or({})/ParseConfirmationTokens(*json, *wallet).value_or(ConfirmationTokenList{})/g' "$TERMUX_PKG_SRCDIR/brave/components/brave_ads/core/internal/legacy_migration/confirmations/legacy_confirmation_migration.cc"
		sed -i 's/ParsePaymentTokens(\*json)\.value_or({})/ParsePaymentTokens(*json).value_or(PaymentTokenList{})/g' "$TERMUX_PKG_SRCDIR/brave/components/brave_ads/core/internal/legacy_migration/confirmations/legacy_confirmation_migration.cc"
	fi
	if [ -f "$TERMUX_PKG_SRCDIR/brave/components/brave_wallet/browser/polkadot/polkadot_utils.cc" ]; then
		sed -i 's/str = base::RemovePrefix(str, "0x")\.value_or({})/str = base::RemovePrefix(str, "0x").value_or(std::string_view{})/g' "$TERMUX_PKG_SRCDIR/brave/components/brave_wallet/browser/polkadot/polkadot_utils.cc"
	fi
	if [ -f "$TERMUX_PKG_SRCDIR/brave/components/brave_wallet/common/hex_utils.cc" ]; then
		sed -i 's/input = base::RemovePrefix(input, "0x")\.value_or({})/input = base::RemovePrefix(input, "0x").value_or(std::string_view{})/g' "$TERMUX_PKG_SRCDIR/brave/components/brave_wallet/common/hex_utils.cc"
	fi

	# Use prebuilt swiftshader
	mv $TERMUX_PKG_SRCDIR/third_party/swiftshader $TERMUX_PKG_SRCDIR/third_party/swiftshader.unused
	mkdir -p $TERMUX_PKG_SRCDIR/third_party/swiftshader/
	cp -Rf $TERMUX_PKG_BUILDER_DIR/third_party_override/swiftshader/* $TERMUX_PKG_SRCDIR/third_party/swiftshader/
}

termux_step_configure() {
	cd $TERMUX_PKG_SRCDIR
	termux_setup_ninja

	# Ensure brave/.env exists
	mkdir -p "$TERMUX_PKG_SRCDIR/brave"
	touch "$TERMUX_PKG_SRCDIR/brave/.env"

	# Fetch depot_tools
	export DEPOT_TOOLS_UPDATE=0
	if [ ! -f "$TERMUX_PKG_CACHEDIR/.depot_tools-fetched" ];then
		git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $TERMUX_PKG_CACHEDIR/depot_tools
		touch "$TERMUX_PKG_CACHEDIR/.depot_tools-fetched"
	fi
	export PATH="$TERMUX_PKG_CACHEDIR/depot_tools:$PATH"
	export PYTHONPATH="$TERMUX_PKG_SRCDIR/brave/script:$TERMUX_PKG_SRCDIR/tools/grit/grit/extern:$TERMUX_PKG_SRCDIR/brave/vendor/requests:$TERMUX_PKG_SRCDIR/build:$TERMUX_PKG_SRCDIR/third_party/depot_tools${PYTHONPATH:+:$PYTHONPATH}"
	$TERMUX_PKG_CACHEDIR/depot_tools/ensure_bootstrap

	# Write gpu/webgpu/dawn_commit_hash.h
	if [ ! -f "$TERMUX_PKG_SRCDIR/gpu/webgpu/dawn_commit_hash.h" ]; then
		cat << EOF > $TERMUX_PKG_SRCDIR/gpu/webgpu/dawn_commit_hash.h
/* Generated by lastchange.py, do not edit.*/

#ifndef GPU_WEBGPU_DAWN_COMMIT_HASH_H_
#define GPU_WEBGPU_DAWN_COMMIT_HASH_H_

#define DAWN_COMMIT_HASH "$(cat $TERMUX_PKG_SRCDIR/gpu/webgpu/DAWN_VERSION)"

#endif  // GPU_WEBGPU_DAWN_COMMIT_HASH_H_
EOF
	fi

	# Remove termux's dummy pkg-config
	rm -rf $TERMUX_PKG_CACHEDIR/host-pkg-config-bin
	mkdir -p $TERMUX_PKG_CACHEDIR/host-pkg-config-bin
	ln -s /usr/bin/pkg-config "$TERMUX_PKG_CACHEDIR"/host-pkg-config-bin/pkg-config
	export PATH="$TERMUX_PKG_CACHEDIR/host-pkg-config-bin:$PATH"

	# Install amd64 rootfs
	build/linux/sysroot_scripts/install-sysroot.py --arch=amd64
	local _amd64_sysroot_path="$(pwd)/build/linux/$(ls build/linux | grep 'amd64-sysroot')"

	# Setup rust toolchain and clang toolchain
	./tools/rust/update_rust.py
	python3 brave/build/rust/download_rust_toolchain_aux.py
	./tools/clang/scripts/update.py

	# Link to system tools required by the build
	ln -sf $(command -v java) third_party/jdk/current/bin/

	# Install nodejs
	if [ ! -f "third_party/node/linux/node-linux-x64/bin/node" ]; then
		./third_party/node/update_node_binaries
	fi
	export PATH="$TERMUX_PKG_SRCDIR/third_party/node/linux/node-linux-x64/bin:$PATH"

	# Install Brave npm dependencies if needed
	if [ ! -d "$TERMUX_PKG_SRCDIR/brave/node_modules/fs-extra" ]; then
		pushd "$TERMUX_PKG_SRCDIR/brave"
		git config --global url."https://github.com/".insteadOf "git@github.com:"
		git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
		npm install
		popd
	fi

	# Install Web Discovery Project dependencies if needed
	if [ -d "$TERMUX_PKG_SRCDIR/brave/vendor/web-discovery-project" ] && [ ! -d "$TERMUX_PKG_SRCDIR/brave/vendor/web-discovery-project/node_modules/colors" ]; then
		pushd "$TERMUX_PKG_SRCDIR/brave/vendor/web-discovery-project"
		npm install --no-save --yes
		popd
	fi

	# Download npm deps
	if [ ! -d "third_party/node/node_modules" ]; then
		local _npm_object_name=$(python -c "Var = str
Str = str
exec(open('$TERMUX_PKG_SRCDIR/DEPS').read())
print(deps['src/third_party/node/node_modules']['objects'][0]['object_name'])
")
		local _npm_sha256sum=$(python -c "Var = str
Str = str
exec(open('$TERMUX_PKG_SRCDIR/DEPS').read())
print(deps['src/third_party/node/node_modules']['objects'][0]['sha256sum'])
")
		local _npm_file="$TERMUX_PKG_SRCDIR/third_party/node/node_modules.tar.gz"
		termux_download \
			"https://commondatastorage.googleapis.com/chromium-nodejs/$_npm_object_name" \
			"${_npm_file}" \
			"${_npm_sha256sum}"
		mkdir -p $TERMUX_PKG_SRCDIR/third_party/node/node_modules-tmp
		tar -xf "$_npm_file" --strip-components=1 -C "$TERMUX_PKG_SRCDIR/third_party/node/node_modules-tmp"
		mv "$TERMUX_PKG_SRCDIR/third_party/node/node_modules-tmp" "$TERMUX_PKG_SRCDIR/third_party/node/node_modules"
	fi

	# Sync rollup-related native deps in devtools
	if [ ! -d "third_party/devtools-frontend/src/node_modules/@rollup/rollup-linux-x64-gnu" ]; then
		if [ ! -f "third_party/devtools-frontend/src/third_party/rollup_libs/rollup.linux-x64-gnu.node" ]; then
			termux_error_exit "rollup.linux-x64-gnu.node not found"
		fi
		pushd third_party/devtools-frontend/src
		python3 scripts/deps/sync_rollup_libs.py
		popd # third_party/devtools-frontend/src
	fi

	local CARGO_TARGET_NAME="${TERMUX_ARCH}-linux-android"
	if [[ "${TERMUX_ARCH}" == "arm" ]]; then
		CARGO_TARGET_NAME="armv7-linux-androideabi"
	fi

	# Dummy librt.so
	# Why not dummy a librt.a? Some of the binaries reference symbols only exists in Android
	# for some reason, such as the `chrome_crashpad_handler`, which needs to link with
	# libprotobuf_lite.a, but it is hard to remove the usage of `android/log.h` in protobuf.
	echo "INPUT(-llog -liconv -landroid-shmem)" > "$TERMUX_PREFIX/lib/librt.so"

	# Dummy libpthread.a and libresolv.a
	echo '!<arch>' > "$TERMUX_PREFIX/lib/libpthread.a"
	echo '!<arch>' > "$TERMUX_PREFIX/lib/libresolv.a"

	# Symlink libffi.a to libffi_pic.a
	ln -sfr $TERMUX_PREFIX/lib/libffi.a $TERMUX_PREFIX/lib/libffi_pic.a

	# Merge sysroots
	if [ ! -d "$TERMUX_PKG_CACHEDIR/sysroot-$TERMUX_ARCH" ]; then
		rm -rf $TERMUX_PKG_TMPDIR/sysroot
		mkdir -p $TERMUX_PKG_TMPDIR/sysroot
		pushd $TERMUX_PKG_TMPDIR/sysroot
		mkdir -p usr/include usr/lib usr/bin
		cp -R $TERMUX_STANDALONE_TOOLCHAIN/sysroot/usr/include/* usr/include
		cp -R $TERMUX_STANDALONE_TOOLCHAIN/sysroot/usr/include/$TERMUX_HOST_PLATFORM/* usr/include
		cp -R $TERMUX_STANDALONE_TOOLCHAIN/sysroot/usr/lib/$TERMUX_HOST_PLATFORM/$TERMUX_PKG_API_LEVEL/* usr/lib/
		cp "$TERMUX_STANDALONE_TOOLCHAIN/sysroot/usr/lib/$TERMUX_HOST_PLATFORM/libc++_shared.so" usr/lib/
		cp "$TERMUX_STANDALONE_TOOLCHAIN/sysroot/usr/lib/$TERMUX_HOST_PLATFORM/libc++_static.a" usr/lib/
		cp "$TERMUX_STANDALONE_TOOLCHAIN/sysroot/usr/lib/$TERMUX_HOST_PLATFORM/libc++abi.a" usr/lib/
		cp -Rf $TERMUX_PREFIX/include/* usr/include
		cp -Rf $TERMUX_PREFIX/lib/* usr/lib
		rm -rf usr/include/c++
		ln -sf /data ./data
		# This is needed to build cups
		cp -Rf $TERMUX_PREFIX/bin/cups-config usr/bin/
		chmod +x usr/bin/cups-config
		# Temporarily disable check
		# Will be enabled after investigating how to correctly append android build target flags to `bindgen`
		patch -p1 < $TERMUX_PKG_BUILDER_DIR/9999-sysroot-disable-target-check.diff
		popd
		mv $TERMUX_PKG_TMPDIR/sysroot $TERMUX_PKG_CACHEDIR/sysroot-$TERMUX_ARCH
	fi

	# Construct args
	local _clang_base_path="$PWD/third_party/llvm-build/Release+Asserts"
	local _host_cc="$_clang_base_path/bin/clang"
	local _host_cxx="$_clang_base_path/bin/clang++"
	local _host_clang_version=$($_host_cc --version | grep -m1 version | sed -E 's|.*\bclang version ([0-9]+).*|\1|')
	local _target_clang_base_path="$TERMUX_STANDALONE_TOOLCHAIN"
	local _target_cc="$_target_clang_base_path/bin/clang"
	local _target_clang_version=$($_target_cc --version | grep -m1 version | sed -E 's|.*\bclang version ([0-9]+).*|\1|')
	local _target_cpu _target_sysroot="$TERMUX_PKG_CACHEDIR/sysroot-$TERMUX_ARCH"
	local _v8_toolchain_name _v8_current_cpu _v8_sysroot_path
	if [ "$TERMUX_ARCH" = "aarch64" ]; then
		_target_cpu="arm64"
		_v8_current_cpu="arm64"
		_v8_sysroot_path="$_amd64_sysroot_path"
		_v8_toolchain_name="host"
	elif [ "$TERMUX_ARCH" = "arm" ]; then
		# Install i386 rootfs
		build/linux/sysroot_scripts/install-sysroot.py --arch=i386
		local _i386_sysroot_path="$(pwd)/build/linux/$(ls build/linux | grep 'i386-sysroot')"
		_target_cpu="arm"
		_v8_current_cpu="x86"
		_v8_sysroot_path="$_i386_sysroot_path"
		_v8_toolchain_name="clang_x86_v8_arm"
	elif [ "$TERMUX_ARCH" = "x86_64" ]; then
		_target_cpu="x64"
		_v8_current_cpu="x64"
		_v8_sysroot_path="$_amd64_sysroot_path"
		_v8_toolchain_name="host"
	fi

	local _common_args_file=$TERMUX_PKG_TMPDIR/common-args-file
	rm -f $_common_args_file
	touch $_common_args_file

	echo "
# Non-official release build without proprietary keys
is_official_build = false
is_debug = false
symbol_level = 0
bitflyer_production_fee_address = \"dummy\"
bitflyer_production_url = \"https://no-thanks.invalid\"
uphold_production_api_url = \"https://no-thanks.invalid\"
uphold_production_fee_address = \"dummy\"
uphold_production_oauth_url = \"https://no-thanks.invalid\"
zebpay_production_api_url = \"https://no-thanks.invalid\"
zebpay_production_oauth_url = \"https://no-thanks.invalid\"
rewards_grant_dev_endpoint = \"https://no-thanks.invalid\"
rewards_grant_staging_endpoint = \"https://no-thanks.invalid\"
rewards_grant_prod_endpoint = \"https://no-thanks.invalid\"
enable_brave_wallet = false
translate_genders = false
# Use our custom toolchain
clang_version = \"$_host_clang_version\"
use_sysroot = false
target_cpu = \"$_target_cpu\"
target_rpath = \"$TERMUX_PREFIX/lib\"
target_sysroot = \"$_target_sysroot\"
custom_toolchain = \"//build/toolchain/linux/unbundle:default\"
custom_toolchain_clang_base_path = \"$_target_clang_base_path\"
custom_toolchain_clang_version = \"$_target_clang_version\"
host_toolchain = \"$TERMUX_PKG_CACHEDIR/custom-toolchain:host\"
v8_snapshot_toolchain = \"$TERMUX_PKG_CACHEDIR/custom-toolchain:$_v8_toolchain_name\"
clang_use_chrome_plugins = false
dcheck_always_on = false
chrome_pgo_phase = 0
treat_warnings_as_errors = false
# Use system libraries as little as possible
use_system_freetype = false
use_custom_libcxx = false
use_custom_libcxx_for_host = true
use_clang_modules = false
use_allocator_shim = false
use_partition_alloc_as_malloc = false
enable_backup_ref_ptr_slow_checks = false
enable_dangling_raw_ptr_checks = false
enable_dangling_raw_ptr_feature_flag = false
backup_ref_ptr_extra_oob_checks = false
enable_backup_ref_ptr_support = false
enable_pointer_compression_support = false
use_nss_certs = true
use_udev = false
use_ozone = true
ozone_auto_platforms = false
ozone_platform = \"x11\"
ozone_platform_x11 = true
# TODO: Enable wayland
ozone_platform_wayland = false
ozone_platform_headless = true
angle_enable_vulkan = true
angle_enable_swiftshader = true
angle_enable_abseil = false
# Use Chrome-branded ffmpeg for more codecs
is_component_ffmpeg = true
ffmpeg_branding = \"Chrome\"
proprietary_codecs = true
use_qt5 = false
use_qt6 = false
use_libpci = false
use_alsa = false
use_pulseaudio = true
rtc_use_pipewire = false
use_vaapi = false
# Host compiler (clang-13) doesn't support LTO well
is_cfi = false
use_cfi_icall = false
use_thin_lto = false
# Enable rust
custom_target_rust_abi_target = \"$CARGO_TARGET_NAME\"
clang_warning_suppression_file = \"\"
exclude_unwind_tables = false
# Enable jumbo build (unified build)
use_jumbo_build = true
# Compile pdfium as a static library
pdf_is_complete_lib = true
enable_pseudolocales = false
" > $_common_args_file

	if [ "$TERMUX_ARCH" = "arm" ]; then
		echo "arm_arch = \"armv7-a\"" >> $_common_args_file
		echo "arm_float_abi = \"softfp\"" >> $_common_args_file
	fi

	# Use custom toolchain
	rm -rf $TERMUX_PKG_CACHEDIR/custom-toolchain
	mkdir -p $TERMUX_PKG_CACHEDIR/custom-toolchain
	cp -f $TERMUX_PKG_BUILDER_DIR/toolchain-template/host-toolchain.gn.in $TERMUX_PKG_CACHEDIR/custom-toolchain/BUILD.gn
	sed -i "s|@HOST_CC@|$_host_cc|g
			s|@HOST_CXX@|$_host_cxx|g
			s|@HOST_LD@|$_host_cxx|g
			s|@HOST_AR@|$(command -v llvm-ar)|g
			s|@HOST_NM@|$(command -v llvm-nm)|g
			s|@HOST_IS_CLANG@|true|g
			s|@HOST_SYSROOT@|$_amd64_sysroot_path|g
			s|@V8_CURRENT_CPU@|$_target_cpu|g
			" $TERMUX_PKG_CACHEDIR/custom-toolchain/BUILD.gn
	if [ "$_v8_toolchain_name" != "host" ]; then
		cat $TERMUX_PKG_BUILDER_DIR/toolchain-template/v8-toolchain.gn.in >> $TERMUX_PKG_CACHEDIR/custom-toolchain/BUILD.gn
		sed -i "s|@V8_CC@|$_host_cc|g
				s|@V8_CXX@|$_host_cxx|g
				s|@V8_LD@|$_host_cxx|g
				s|@V8_AR@|$(command -v llvm-ar)|g
				s|@V8_NM@|$(command -v llvm-nm)|g
				s|@V8_TOOLCHAIN_NAME@|$_v8_toolchain_name|g
				s|@V8_CURRENT_CPU@|$_v8_current_cpu|g
				s|@V8_V8_CURRENT_CPU@|$_target_cpu|g
				s|@V8_IS_CLANG@|true|g
				s|@V8_SYSROOT@|$_v8_sysroot_path|g
				" $TERMUX_PKG_CACHEDIR/custom-toolchain/BUILD.gn
	fi

	# Generate ninja files
	mkdir -p $TERMUX_PKG_BUILDDIR/out/Release
	cat $_common_args_file > $TERMUX_PKG_BUILDDIR/out/Release/args.gn
	gn gen $TERMUX_PKG_BUILDDIR/out/Release

	# Redirect upstream Chromium sources to Brave overrides in non-jumbo targets
	python3 -c "
import os, glob
build_dir = '$TERMUX_PKG_BUILDDIR/out/Release'
src_dir = '$TERMUX_PKG_SRCDIR'
brave_src_dir = os.path.join(src_dir, 'brave/chromium_src')
for ninja_file in glob.glob(os.path.join(build_dir, '**/*.ninja'), recursive=True):
    with open(ninja_file, 'r', errors='ignore') as f:
        lines = f.readlines()
    modified = False
    new_lines = []
    for line in lines:
        if line.startswith('build ') and (': cxx ' in line or ': cc ' in line):
            rule = ': cxx ' if ': cxx ' in line else ': cc '
            parts = line.split(rule)
            before = parts[0] + rule
            tokens = parts[1].split(' ')
            src_file = tokens[0]
            override_path = None
            if src_file.startswith('gen/') and not 'brave/chromium_src' in src_file:
                cand = os.path.join(brave_src_dir, src_file[4:])
                if os.path.exists(cand):
                    override_path = cand
            elif 'src/' in src_file and not 'brave/chromium_src' in src_file:
                full_src_path = os.path.normpath(os.path.join(build_dir, src_file))
                rel = os.path.relpath(full_src_path, src_dir)
                cand = os.path.join(brave_src_dir, rel)
                if os.path.exists(cand):
                    override_path = cand
            if override_path:
                tokens[0] = os.path.relpath(override_path, build_dir)
                new_lines.append(before + ' '.join(tokens))
                modified = True
                continue
        new_lines.append(line)
    if modified:
        with open(ninja_file, 'w') as f:
            f.writelines(new_lines)
"
}

termux_step_make() {
	cd $TERMUX_PKG_BUILDDIR
	export PATH="$TERMUX_PKG_SRCDIR/third_party/node/linux/node-linux-x64/bin:$PATH"
	export PYTHONPATH="$TERMUX_PKG_SRCDIR/brave/script:$TERMUX_PKG_SRCDIR/tools/grit/grit/extern:$TERMUX_PKG_SRCDIR/brave/vendor/requests:$TERMUX_PKG_SRCDIR/build:$TERMUX_PKG_SRCDIR/third_party/depot_tools${PYTHONPATH:+:$PYTHONPATH}"

	local _ninja_jobs="-j ${TERMUX_PKG_MAKE_PROCESSES:-24}"

	# Build v8 snapshot in another action
	time ninja $_ninja_jobs -C out/Release \
						v8_context_snapshot \
						run_mksnapshot_default \
						run_torque \
						generate_bytecode_builtins_list \
						v8:run_gen-regexp-special-case

	# Build generate steps in another action
	time ninja $_ninja_jobs -C out/Release \
						generate_top_domain_list_variables_file \
						generate_chrome_colors_info \
						character_data \
						gen_root_store_inc \
						generate_transport_security_state \
						generate_top_domains_trie

	# Build swiftshader in another action
	time ninja $_ninja_jobs -C out/Release \
						third_party/swiftshader/src/Vulkan:icd_file \
						third_party/swiftshader/src/Vulkan:swiftshader_libvulkan

	# Build pdfium in another action
	time ninja $_ninja_jobs -C out/Release \
						third_party/pdfium \
						third_party/pdfium:pdfium_public_headers

	# Build other components
	ninja $_ninja_jobs -C out/Release chrome chromedriver chrome_crashpad_handler headless_shell
	cp -f out/Release/chrome out/Release/brave
}

termux_step_make_install() {
	cd $TERMUX_PKG_BUILDDIR
	mkdir -p $TERMUX_PREFIX/lib/brave

	local normal_files=(
		# Binary files
		brave
		chrome_crashpad_handler
		headless_shell
		chromedriver
		generate_colors_info

		# Resource files
		brave_100_percent.pak
		brave_200_percent.pak
		brave_resources.pak
		chrome_100_percent.pak
		chrome_200_percent.pak
		headless_lib_data.pak
		headless_lib_strings.pak
		resources.pak

		# V8 Snapshot data
		snapshot_blob.bin
		v8_context_snapshot.bin

		# ICU Data
		icudtl.dat

		# Angle
		libEGL.so
		libGLESv2.so

		# Vulkan
		libvulkan.so.1
		libVkICD_mock_icd.so
		libvk_swiftshader.so
		libVkLayer_khronos_validation.so
		vk_swiftshader_icd.json

		# FFmpeg
		libffmpeg.so
	)

	cp "${normal_files[@]/#/out/Release/}" "$TERMUX_PREFIX/lib/brave/"

	cp -Rf out/Release/angledata $TERMUX_PREFIX/lib/brave/
	cp -Rf out/Release/locales $TERMUX_PREFIX/lib/brave/
	cp -Rf out/Release/MEIPreload $TERMUX_PREFIX/lib/brave/
	cp -Rf out/Release/resources $TERMUX_PREFIX/lib/brave/

	sed "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" \
		$TERMUX_PKG_BUILDER_DIR/brave-launcher.sh.in > $TERMUX_PREFIX/lib/brave/brave-launcher.sh
	chmod +x $TERMUX_PREFIX/lib/brave/brave-launcher.sh

	ln -sfr $TERMUX_PREFIX/lib/brave/brave-launcher.sh $TERMUX_PREFIX/bin/brave-browser
	ln -sfr $TERMUX_PREFIX/lib/brave/brave-launcher.sh $TERMUX_PREFIX/bin/brave
	ln -sfr $TERMUX_PREFIX/lib/brave/chromedriver $TERMUX_PREFIX/bin/
	ln -sfr $TERMUX_PREFIX/lib/brave/headless_shell $TERMUX_PREFIX/bin/

	# Install man pages and desktop files
	install -Dm644 $TERMUX_PKG_SRCDIR/chrome/app/resources/manpage.1.in \
		"$TERMUX_PREFIX/share/man/man1/brave.1"
	install -Dm644 $TERMUX_PKG_SRCDIR/chrome/installer/linux/common/desktop.template \
		"$TERMUX_PREFIX/share/applications/brave-browser.desktop"
	sed -i \
		-e 's/@@MENUNAME/Brave/g' \
		-e 's/@@PACKAGE/brave-browser/g' \
		-e 's/@@usr_bin_symlink_name/brave-browser/g' \
		-e 's|@@uri_scheme|x-scheme-handler/brave;|g' \
		-e 's/@@extra_desktop_entries//g' \
		-e "s|Exec=/usr/bin|Exec=$TERMUX_PREFIX/bin|g" \
		"$TERMUX_PREFIX/share/applications/brave-browser.desktop" \
		"$TERMUX_PREFIX/share/man/man1/brave.1"

	# Install logos
	for size in 24 48 64 128 256; do
		if [ -f "$TERMUX_PKG_SRCDIR/brave/app/theme/brave/product_logo_$size.png" ]; then
			install -Dm644 "$TERMUX_PKG_SRCDIR/brave/app/theme/brave/product_logo_$size.png" \
				"$TERMUX_PREFIX/share/icons/hicolor/${size}x${size}/apps/brave-browser.png"
		elif [ -f "$TERMUX_PKG_SRCDIR/chrome/app/theme/chromium/product_logo_$size.png" ]; then
			install -Dm644 "$TERMUX_PKG_SRCDIR/chrome/app/theme/chromium/product_logo_$size.png" \
				"$TERMUX_PREFIX/share/icons/hicolor/${size}x${size}/apps/brave-browser.png"
		fi
	done

	for size in 16 32; do
		if [ -f "$TERMUX_PKG_SRCDIR/brave/app/theme/default_100_percent/brave/product_logo_$size.png" ]; then
			install -Dm644 "$TERMUX_PKG_SRCDIR/brave/app/theme/default_100_percent/brave/product_logo_$size.png" \
				"$TERMUX_PREFIX/share/icons/hicolor/${size}x${size}/apps/brave-browser.png"
		elif [ -f "$TERMUX_PKG_SRCDIR/chrome/app/theme/default_100_percent/chromium/product_logo_$size.png" ]; then
			install -Dm644 "$TERMUX_PKG_SRCDIR/chrome/app/theme/default_100_percent/chromium/product_logo_$size.png" \
				"$TERMUX_PREFIX/share/icons/hicolor/${size}x${size}/apps/brave-browser.png"
		fi
	done

	# Install AppStream metadata file
	install -Dm644 $TERMUX_PKG_SRCDIR/chrome/installer/linux/common/appdata.xml.template \
		"$TERMUX_PREFIX/share/metainfo/brave.appdata.xml"
	sed -ni \
		-e 's/chromium-browser\.desktop/brave-browser.desktop/' \
		-e '/<update_contact>/d' \
		-e '/<p>/N;/<p>\n.*\(We invite\|Chromium supports Vorbis\)/,/<\/p>/d' \
		-e '/^<?xml/,$p' \
		"$TERMUX_PREFIX/share/metainfo/brave.appdata.xml"
}

termux_step_post_make_install() {
	# Remove the dummy files
	rm $TERMUX_PREFIX/lib/lib{{pthread,resolv,ffi_pic}.a,rt.so}
}

# TODO:
# (2) Split packages

# ######################### About system libraries ############################
# We only pick up a few libraries to let chromium link against. Others may
# contain linking error due to the version mismatch between Google-provided
# sysroot and Termux.
# Name in Chromium | libdrm fontconfig
# Name in Termux   | libdrm fontconfig
#
# #############################################################################

# ############################ About Sandbox ##################################
# First, setuid-sandbox is never usable on Termux, beacuse setuid syscall is
# disabled by Android's SELinux. Second, lots of patches are needed to let
# seccomp-bpf sandbox work properly on Android. I've tried many times but I
# can't make it. If your are willing to work on this, feel free to submit a PR.
# #############################################################################
