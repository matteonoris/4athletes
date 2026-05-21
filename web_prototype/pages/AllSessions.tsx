import React from 'react';
import { ArrowLeft, Search } from 'lucide-react';
import { ViewState, TrainingSession } from '../types';
import { sportsData } from '../data/sports';

interface Props {
  setView: (view: ViewState) => void;
  sessions: TrainingSession[];
  onSessionClick?: (sessionId: string) => void;
}

const AllSessions: React.FC<Props> = ({ setView, sessions, onSessionClick }) => {
  
  const getSportData = (id: string) => sportsData.find(s => s.id === id) || sportsData[0];

  return (
    <div className="min-h-screen bg-background relative flex flex-col">
      <header className="sticky top-0 z-20 bg-background/95 backdrop-blur p-4 pb-2 border-b border-white/5 flex items-center justify-between">
        <button onClick={() => setView('analytics')} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft className="text-white" />
        </button>
        <h1 className="font-bold text-lg flex-1 text-center">Training History</h1>
        <div className="w-10"></div>
      </header>

      {/* Simple Search/Filter Bar */}
      <div className="p-4 border-b border-white/5 sticky top-[65px] bg-background z-10">
         <div className="relative">
            <Search className="absolute left-3 top-2.5 w-4 h-4 text-gray-500" />
            <input 
                type="text" 
                placeholder="Search history..." 
                className="w-full bg-surface border-none rounded-lg py-2 pl-9 pr-4 text-sm text-white focus:ring-1 focus:ring-secondary"
            />
         </div>
      </div>

      <div className="flex-1 p-4 space-y-4 overflow-y-auto">
        {sessions.length > 0 ? (
          sessions.map((session) => {
            const sport = getSportData(session.sportId);
            const SportIcon = sport.icon;
            
            return (
              <div 
                key={session.id} 
                onClick={() => onSessionClick && onSessionClick(session.id)}
                className="bg-card rounded-2xl p-4 border border-white/5 flex gap-4 cursor-pointer active:scale-[0.98] transition hover:border-white/20 animate-in fade-in slide-in-from-bottom-2 duration-300"
              >
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${session.sportId === 'alpine_skiing' ? 'bg-secondary/10' : 'bg-orange-500/10'}`}>
                   <SportIcon className={`w-6 h-6 ${session.sportId === 'alpine_skiing' ? 'text-secondary' : 'text-orange-500'}`} />
                </div>
                <div className="flex-1">
                  <div className="flex justify-between items-start">
                     <div>
                        <h3 className="font-semibold text-base">{sport.name}</h3>
                        <span className="text-xs text-gray-500 font-medium">{session.date === new Date().toISOString().split('T')[0] ? 'Today' : session.date}</span>
                     </div>
                     <span className="text-xs font-bold bg-white/5 px-2 py-1 rounded text-gray-400">{session.startTime}</span>
                  </div>
                  
                  {session.details?.specialties ? (
                     <p className="text-sm text-gray-300 mt-1">{session.details.specialties.join(', ')}</p>
                  ) : (
                     <p className="text-sm text-gray-300 mt-1">General Training</p>
                  )}
                  
                  <div className="flex items-center gap-3 mt-3 pt-3 border-t border-white/5 text-xs text-gray-400 font-mono">
                    <span className="flex items-center gap-1">
                        <span className="w-1.5 h-1.5 bg-gray-500 rounded-full"></span>
                        {session.duration}
                    </span>
                    <span className="flex items-center gap-1">
                        <span className={`w-1.5 h-1.5 rounded-full ${session.effort > 7 ? 'bg-orange-500' : session.effort > 4 ? 'bg-secondary' : 'bg-green-500'}`}></span>
                        RPE {session.effort}/10
                    </span>
                  </div>
                </div>
              </div>
            );
          })
        ) : (
          <div className="flex flex-col items-center justify-center py-20 opacity-50">
            <div className="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mb-4">
                <Search className="w-8 h-8 text-gray-400" />
            </div>
            <p className="text-gray-400">No training sessions found.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default AllSessions;