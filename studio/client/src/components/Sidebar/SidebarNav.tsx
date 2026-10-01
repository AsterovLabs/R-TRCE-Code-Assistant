/**
 * studio/client/src/components/Sidebar/SidebarNav.tsx -- Activity Bar Navigation
 */

import React from 'react';
import { Files, Network, ShieldAlert, AlertTriangle, HelpCircle } from 'lucide-react';
import { SidebarTab } from '../../types';

interface SidebarNavProps {
  activeTab: SidebarTab;
  onTabChange: (tab: SidebarTab) => void;
  pitfallCount?: number;
  coveragePct?: number;
}

export const SidebarNav: React.FC<SidebarNavProps> = ({
  activeTab,
  onTabChange,
  pitfallCount = 0,
  coveragePct
}) => {
  const tabs: { id: SidebarTab; label: string; icon: React.ComponentType<{ className?: string }>; badge?: string | number; badgeColor?: string }[] = [
    { id: 'files', label: 'Explorer', icon: Files },
    { id: 'ast', label: 'AST Archetypes', icon: Network },
    {
      id: 'trce',
      label: 'TRCE Telemetry',
      icon: ShieldAlert,
      badge: coveragePct !== undefined ? `${Math.round(coveragePct)}%` : undefined,
      badgeColor: coveragePct === 100 ? 'bg-rt-green/20 text-rt-green' : 'bg-rt-yellow/20 text-rt-yellow'
    },
    {
      id: 'pitfalls',
      label: 'Pitfall Sentinel',
      icon: AlertTriangle,
      badge: pitfallCount > 0 ? pitfallCount : undefined,
      badgeColor: 'bg-rt-red/20 text-rt-red'
    },
    { id: 'quiz', label: 'Tutor & Quiz', icon: HelpCircle }
  ];

  return (
    <div className="w-12 bg-rt-crust border-r border-rt-surface-0 flex flex-col items-center py-2 space-y-2 select-none flex-shrink-0">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        const isActive = activeTab === tab.id;
        return (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            className={`relative p-2.5 rounded-lg transition group ${
              isActive
                ? 'bg-rt-surface-0 text-rt-mauve'
                : 'text-rt-text-faint hover:text-rt-text hover:bg-rt-surface-0/50'
            }`}
            title={tab.label}
          >
            <Icon className="w-5 h-5" />
            {tab.badge !== undefined && (
              <span className={`absolute -top-1 -right-1 text-[9px] font-mono font-bold px-1 rounded-full ${tab.badgeColor}`}>
                {tab.badge}
              </span>
            )}
            {/* Active tab marker bar */}
            {isActive && (
              <span className="absolute left-0 top-1.5 bottom-1.5 w-0.5 bg-rt-mauve rounded-r" />
            )}
          </button>
        );
      })}
    </div>
  );
};
