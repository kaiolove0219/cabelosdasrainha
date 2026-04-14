"use client";

import { Boxes, Sparkles, Zap } from "lucide-react";

const items = [
  { icon: Boxes, label: "Next.js" },
  { icon: Zap, label: "Turbopack" },
  { icon: Sparkles, label: "Lucide" },
];

export function DevelopmentStackBadge() {
  if (process.env.NODE_ENV !== "development") {
    return null;
  }

  return (
    <div className="stack-badge" aria-hidden="true">
      {items.map(({ icon: Icon, label }) => (
        <div className="stack-badge__item" key={label}>
          <Icon size={16} strokeWidth={2.2} />
          <span>{label}</span>
        </div>
      ))}
    </div>
  );
}

