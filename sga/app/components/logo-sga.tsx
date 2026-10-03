// Logo del SGA: hexágono blanco con "SGA" e "ITBA".
export default function LogoSga({ size = 58, className }: { size?: number; className?: string }) {
  return (
    <svg
      aria-label="SGA ITBA"
      className={className}
      height={size}
      role="img"
      viewBox="0 0 100 112"
      width={(size * 100) / 112}
    >
      <polygon fill="#fff" points="50,2 97,29 97,83 50,110 3,83 3,29" />
      <text
        fill="#005288"
        fontFamily="Arial Narrow, Arial, sans-serif"
        fontSize="48"
        lengthAdjust="spacingAndGlyphs"
        textAnchor="middle"
        textLength="66"
        x="50"
        y="64"
      >
        SGA
      </text>
      <text fill="#1b3f6b" fontFamily="Arial, sans-serif" fontSize="17" fontWeight="700" textAnchor="middle" x="50" y="86">
        ITBA
      </text>
    </svg>
  );
}
