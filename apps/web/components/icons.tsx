interface IconProps {
  className?: string;
}

export const AppleIcon = ({ className }: IconProps) => (
  <svg
    viewBox="0 0 24 24"
    fill="currentColor"
    aria-hidden="true"
    className={className}
  >
    <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701" />
  </svg>
);

export const GitHubIcon = ({ className }: IconProps) => (
  <svg
    viewBox="0 0 24 24"
    fill="currentColor"
    aria-hidden="true"
    className={className}
  >
    <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
  </svg>
);

export const CopyIcon = ({ className }: IconProps) => (
  <svg
    viewBox="0 0 16 16"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.5"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
    className={className}
  >
    <rect x="5.25" y="5.25" width="8.5" height="8.5" rx="2" />
    <path d="M10.75 3.25A1.75 1.75 0 0 0 9 2.25H4.25a2 2 0 0 0-2 2V9a1.75 1.75 0 0 0 1 1.58" />
  </svg>
);

export const CheckIcon = ({ className }: IconProps) => (
  <svg
    viewBox="0 0 16 16"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.75"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
    className={className}
  >
    <path d="m3.25 8.5 3 3 6.5-7" />
  </svg>
);

export const GearIcon = ({ className }: IconProps) => (
  <svg
    viewBox="0 0 16 16"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.2"
    strokeLinejoin="round"
    aria-hidden="true"
    className={className}
  >
    <path d="M6.8 1.5h2.4l.4 1.7 1.1.6 1.6-.5 1.2 2-1.2 1.2v1l1.2 1.2-1.2 2-1.6-.5-1.1.6-.4 1.7H6.8l-.4-1.7-1.1-.6-1.6.5-1.2-2 1.2-1.2v-1L2.5 5.3l1.2-2 1.6.5 1.1-.6z" />
    <circle cx="8" cy="8" r="2" />
  </svg>
);

export const PlusIcon = ({ className }: IconProps) => (
  <svg
    viewBox="0 0 16 16"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.75"
    strokeLinecap="round"
    aria-hidden="true"
    className={className}
  >
    <path d="M8 3.5v9M3.5 8h9" />
  </svg>
);

// One glyph per kind of VPN, standing in for the SF Symbols the app uses.
export const FortiIcon = ({ className }: IconProps) => (
  <svg viewBox="0 0 16 16" aria-hidden="true" className={className}>
    <path
      fill="currentColor"
      fillRule="evenodd"
      d="M8 1.2 13.2 3v4.6c0 3.2-2.1 5.9-5.2 7.2-3.1-1.3-5.2-4-5.2-7.2V3zM6.9 7.4V6.7a1.1 1.1 0 0 1 2.2 0v.7h.5v3.1H6.4V7.4zm.7 0h.8V6.7a.4.4 0 0 0-.8 0z"
    />
  </svg>
);

export const NetBirdIcon = ({ className }: IconProps) => (
  <svg viewBox="0 0 16 16" aria-hidden="true" className={className}>
    <path
      d="M3.5 4.5h9L8 12.2z"
      fill="none"
      stroke="currentColor"
      strokeWidth="1"
      strokeDasharray="1 1.6"
    />
    <g fill="currentColor">
      <circle cx="3.5" cy="4.5" r="2" />
      <circle cx="12.5" cy="4.5" r="2" />
      <circle cx="8" cy="12.2" r="2" />
    </g>
  </svg>
);

export const OpenConnectIcon = ({ className }: IconProps) => (
  <svg
    viewBox="0 0 16 16"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.2"
    aria-hidden="true"
    className={className}
  >
    <circle cx="8" cy="8" r="6" />
    <path d="M2 8h12M8 2c-2 1.8-2 10.2 0 12M8 2c2 1.8 2 10.2 0 12" />
  </svg>
);

export const WireGuardIcon = ({ className }: IconProps) => (
  <svg viewBox="0 0 16 16" aria-hidden="true" className={className}>
    <path
      fill="currentColor"
      d="M1.5 9.8 6.6 5l2.3 2.6 5.6-1.4L9.4 11 7.1 8.4z"
    />
  </svg>
);
