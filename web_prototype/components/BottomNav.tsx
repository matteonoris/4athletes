import React from 'react';
import { Home, Users, BarChart2, User } from 'lucide-react';
import { ViewState, Language } from '../types';
import { translations } from '../i18n';

interface BottomNavProps {
  currentView: ViewState;
  setView: (view: ViewState) => void;
  language: Language;
}

const BottomNav: React.FC<BottomNavProps> = ({ currentView, setView, language }) => {
  const t = translations[language];

  // Only show nav on main tabs
  const mainTabs = ['home', 'teams', 'analytics', 'profile'];
  if (!mainTabs.includes(currentView)) return null;

  const getIconColor = (view: ViewState) => 
    currentView === view ? 'text-secondary' : 'text-gray-500';

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-surface/95 backdrop-blur border-t border-white/5 pb-safe z-50">
      <div className="flex justify-around items-center h-20">
        <button onClick={() => setView('home')} className="flex flex-col items-center gap-1">
          <Home className={`w-6 h-6 ${getIconColor('home')}`} />
          <span className={`text-[10px] font-medium ${getIconColor('home')}`}>{t.home}</span>
        </button>
        <button onClick={() => setView('teams')} className="flex flex-col items-center gap-1">
          <Users className={`w-6 h-6 ${getIconColor('teams')}`} />
          <span className={`text-[10px] font-medium ${getIconColor('teams')}`}>{t.teams}</span>
        </button>
        <button onClick={() => setView('analytics')} className="flex flex-col items-center gap-1">
          <BarChart2 className={`w-6 h-6 ${getIconColor('analytics')}`} />
          <span className={`text-[10px] font-medium ${getIconColor('analytics')}`}>{t.analytics}</span>
        </button>
        <button onClick={() => setView('profile')} className="flex flex-col items-center gap-1">
          <User className={`w-6 h-6 ${getIconColor('profile')}`} />
          <span className={`text-[10px] font-medium ${getIconColor('profile')}`}>{t.profile}</span>
        </button>
      </div>
    </div>
  );
};

export default BottomNav;