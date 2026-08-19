{ ... }:
{
  xdg.configFile."BeeperTexts/custom.css".text = ''
    /* Tokyo Night theme for Beeper Desktop v4.
     * Palette: Stylix base16 tokyo-night-dark.
     */

    :root {
        --font-family: Inter, system-ui, sans-serif;

        --color-bg: #1a1b26;
        --color-bg-rgb: 26, 27, 38;
        --color-fg: #c0caf5;
        --color-fg-rgb: 192, 202, 245;
        --color-primary: #7aa2f7;
        --color-primary-rgb: 122, 162, 247;

        --color-base-black: #16161e;
        --color-base-black-rgb: 22, 22, 30;
        --color-base-white: #c0caf5;
        --color-base-white-rgb: 192, 202, 245;
        --color-base-gray-10: #16161e;
        --color-base-gray-10-rgb: 22, 22, 30;
        --color-base-gray-20: #1a1b26;
        --color-base-gray-20-rgb: 26, 27, 38;
        --color-base-gray-30: #24283b;
        --color-base-gray-30-rgb: 36, 40, 59;
        --color-base-gray-40: #292e42;
        --color-base-gray-40-rgb: 41, 46, 66;
        --color-base-gray-50: #3b4261;
        --color-base-gray-50-rgb: 59, 66, 97;
        --color-base-gray-60: #565f89;
        --color-base-gray-60-rgb: 86, 95, 137;
        --color-base-gray-80: #737aa2;
        --color-base-gray-80-rgb: 115, 122, 162;
        --color-base-gray-100: #a9b1d6;
        --color-base-gray-100-rgb: 169, 177, 214;
        --color-base-gray-110: #bbbfdb;
        --color-base-gray-110-rgb: 187, 191, 219;
        --color-base-gray-120: #c0caf5;
        --color-base-gray-120-rgb: 192, 202, 245;

        --color-base-system-blue-80: #3d59a1;
        --color-base-system-blue-80-rgb: 61, 89, 161;
        --color-base-system-blue-90: #7aa2f7;
        --color-base-system-blue-90-rgb: 122, 162, 247;
        --color-base-system-blue-100: #89ddff;
        --color-base-system-blue-100-rgb: 137, 221, 255;

        --color-background-app: var(--color-base-gray-10);
        --color-background-app-weak: var(--color-base-gray-20);
        --color-background-elevated: var(--color-base-gray-30);
        --color-background-elevated-hover: var(--color-base-gray-40);
        --color-background-grouped: var(--color-base-gray-20);
        --color-background-grouped-weak: var(--color-base-gray-10);
        --color-background-object: var(--color-base-gray-30);
        --color-background-button-primary: var(--color-base-system-blue-90);
        --color-background-button-primary-active: var(--color-base-system-blue-100);
        --color-background-button-primary-disabled: var(--color-base-system-blue-80);
        --color-background-button-secondary: var(--color-base-gray-40);
        --color-background-button-secondary-active: var(--color-base-gray-50);
        --color-background-button-secondary-disabled: var(--color-base-gray-30);
        --color-background-button-translucent: rgba(var(--color-base-white-rgb), 0.1);
        --color-background-button-translucent-active: rgba(var(--color-base-white-rgb), 0.15);
        --color-background-sidebar: rgba(var(--color-base-gray-30-rgb), 0.8);
        --color-background-sidebar-opaque: var(--color-base-gray-30);
        --color-background-sidebar-thread-focus: rgba(var(--color-base-white-rgb), 0.08);
        --color-background-sidebar-thread-selected: var(--color-base-system-blue-80);
        --color-background-sidebar-thread-selected-unfocused: rgba(var(--color-base-white-rgb), 0.12);
        --color-background-message-active: var(--color-base-gray-30);
        --color-background-message-bubble-received: var(--color-base-gray-40);
        --color-background-message-bubble-sent: #3d59a1;
        --color-background-message-bubble-linked: var(--color-base-gray-20);
        --color-background-selected-primary: var(--color-base-system-blue-80);
        --color-background-selected-secondary: rgba(var(--color-base-white-rgb), 0.1);
        --color-background-input: var(--color-base-gray-10);
        --color-background-kbd: rgba(var(--color-base-white-rgb), 0.15);
        --color-background-header-right: rgba(var(--color-base-gray-20-rgb), 0.94);
        --color-background-header-right-opaque: var(--color-base-gray-20);
        --color-background-menu: rgba(var(--color-base-gray-30-rgb), 0.96);
        --color-background-menu-opaque: var(--color-base-gray-30);
        --color-background-menu-option-hover: var(--color-base-system-blue-80);
        --color-border-neutrals: var(--color-base-gray-50);
        --color-border-neutrals-strong: var(--color-base-gray-60);
        --color-border-neutrals-weak: var(--color-base-gray-40);
        --color-border-input: var(--color-base-gray-50);
        --color-border-input-active: var(--color-base-system-blue-90);
        --color-border-translucent: rgba(var(--color-base-white-rgb), 0.1);
        --color-border-translucent-strong: rgba(var(--color-base-white-rgb), 0.16);
        --color-border-translucent-weak: rgba(var(--color-base-white-rgb), 0.06);
        --color-text-neutrals: var(--color-base-gray-120);
        --color-text-neutrals-subtle: var(--color-base-gray-100);
        --color-text-neutrals-weak: var(--color-base-gray-110);
        --color-text-on-accent: #16161e;
        --color-text-on-accent-weak: rgba(var(--color-base-black-rgb), 0.72);
        --color-text-translucent: rgba(var(--color-base-white-rgb), 0.92);
        --color-text-translucent-subtle: rgba(var(--color-base-white-rgb), 0.55);
        --color-text-translucent-weak: rgba(var(--color-base-white-rgb), 0.72);
        --color-icon-neutrals: var(--color-base-gray-100);
        --color-icon-neutrals-strong: var(--color-base-gray-120);
        --color-icon-neutrals-subtle: var(--color-base-gray-80);
        --color-icon-neutrals-weak: var(--color-base-gray-100);
        --color-icon-translucent: rgba(var(--color-base-white-rgb), 0.6);
        --color-icon-translucent-strong: rgba(var(--color-base-white-rgb), 0.9);
        --color-icon-translucent-subtle: rgba(var(--color-base-white-rgb), 0.3);
        --color-icon-translucent-weak: rgba(var(--color-base-white-rgb), 0.42);
        --color-background-scrollbar: rgba(var(--color-base-white-rgb), 0.24);
        --color-background-scrollbar-hover: rgba(var(--color-base-white-rgb), 0.4);
        --color-background-tag: rgba(var(--color-base-white-rgb), 0.1);
        --color-overlay-modal: rgba(var(--color-base-black-rgb), 0.55);
        --left-pane-bg: transparent;
        --right-pane-bg: var(--color-background-app);
    }

    body {
        font-family: var(--font-family);
        color: var(--color-text-neutrals);
    }

    .bubble-mode .message-contents {
        border-radius: 16px 16px 16px 6px;
    }

    .bubble-mode .is-sender .message-contents {
        border-radius: 16px 16px 6px 16px;
    }

    .bubble-mode .is-sender:not(.type-action):not(.is-deleted) .message-text-container {
        color: var(--color-text-neutrals);
    }

    .ThreadListItem-module__wrapper.ThreadListItem-module__isSelected::before {
        background: var(--color-background-selected-primary);
    }

    .custom-scrollbars ::-webkit-scrollbar-thumb {
        background-color: var(--color-background-scrollbar);
        border-radius: 20px;
    }

    .custom-scrollbars ::-webkit-scrollbar-thumb:hover {
        background-color: var(--color-background-scrollbar-hover);
    }

    .no-transparency,
    .reduce-transparency {
        --left-pane-bg: var(--color-background-sidebar-opaque);
        --color-background-header-right: var(--color-background-header-right-opaque);
        --color-background-menu: var(--color-background-menu-opaque);
    }
  '';
}
