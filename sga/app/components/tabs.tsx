"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

export type Tab = { label: string; href?: string; exact?: boolean };

// Solapas como las del SGA actual. Sin href = no implementada (en gris).
export default function Tabs({ tabs, nivel = 1 }: { tabs: Tab[]; nivel?: 1 | 2 }) {
  const pathname = usePathname();
  return (
    <nav className={`sga-tabs sga-tabs-${nivel}`}>
      {tabs.map((t) => {
        if (!t.href) {
          return <span className="sga-tab is-disabled" key={t.label} title="Próximamente">{t.label}</span>;
        }
        const activa = t.exact ? pathname === t.href : pathname.startsWith(t.href);
        return (
          <Link className={`sga-tab ${activa ? "is-active" : ""}`} href={t.href} key={t.label}>
            {t.label}
          </Link>
        );
      })}
    </nav>
  );
}
