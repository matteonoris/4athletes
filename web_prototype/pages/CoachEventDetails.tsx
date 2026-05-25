
import React, { useState } from 'react';
import { ArrowLeft, Activity, Trophy, Info, Users, CheckCircle, Zap, Snowflake, Search, CheckSquare, Square, Dumbbell } from 'lucide-react';
import { CalendarEvent, Team } from '../types';

interface Props {
  event: CalendarEvent;
  teams: Team[];
  onSave: (event: CalendarEvent) => void;
  onBack: () => void;
}

type Tab = 'info' | 'technical' | 'attendees';

const CoachEventDetails: React.FC<Props> = ({ event, teams, onSave, onBack }) => {
  const [activeTab, setActiveTab] = useState<Tab>('info');
  const [attendeeSearch, setAttendeeSearch] = useState('');
  
  const isNewEvent = !event.id;

  // Local state for editing
  const [editedEvent, setEditedEvent] = useState<CalendarEvent>({
      ...event,
      sportCategory: event.sportCategory || 'ski',
      drylandSpecialty: event.drylandSpecialty || '',
      technicalDetails: event.technicalDetails || {
        snowCondition: '',
        weatherCondition: '',
        specialties: [],
        freeSkiing: { laps: '', changes: '' },
        gatedSkiing: { laps: '', changes: '' }
      },
      attendees: event.attendees || []
  });

  const todayStr = new Date().toISOString().split('T')[0];
  const isPast = editedEvent.date < todayStr;

  const showTechnicalTab = isPast && editedEvent.sportCategory !== 'dryland';
  if (activeTab === 'technical' && !showTechnicalTab) {
      setActiveTab('info');
  }

  const getFilteredAttendees = () => {
      if (!editedEvent.attendees) return [];
      return editedEvent.attendees.filter(a => a.name.toLowerCase().includes(attendeeSearch.toLowerCase()));
  };

  const handleAttendeeToggle = (id: string) => {
      if (!editedEvent.attendees) return;
      const updated = editedEvent.attendees.map(a => a.id === id ? { ...a, isPresent: !a.isPresent } : a);
      setEditedEvent({ ...editedEvent, attendees: updated });
  };

  const handleToggleSelectAll = () => {
      if (!editedEvent.attendees) return;
      const filtered = editedEvent.attendees.filter(a => a.name.toLowerCase().includes(attendeeSearch.toLowerCase()));
      if (filtered.length === 0) return;

      const allSelected = filtered.every(a => a.isPresent);
      const updated = editedEvent.attendees.map(a => {
          if (filtered.some(f => f.id === a.id)) {
              return { ...a, isPresent: !allSelected };
          }
          return a;
      });
      setEditedEvent({ ...editedEvent, attendees: updated });
  };

  const handleOverrideChange = (id: string, val: string) => {
      if (!editedEvent.attendees) return;
      const updated = editedEvent.attendees.map(a => a.id === id ? { ...a, lapsOverride: val } : a);
      setEditedEvent({ ...editedEvent, attendees: updated });
  };

  const toggleSpecialty = (s: string) => {
      if (!editedEvent.technicalDetails) return;
      const current = editedEvent.technicalDetails.specialties || [];
      const updated = current.includes(s) ? current.filter(x => x !== s) : [...current, s];
      setEditedEvent({
          ...editedEvent,
          technicalDetails: { ...editedEvent.technicalDetails, specialties: updated }
      });
  };

  const handleSaveClick = () => {
      // If it's a new event, ensure it has an ID before saving to parent
      const payload = {
          ...editedEvent,
          id: editedEvent.id || Date.now().toString()
      };
      onSave(payload);
  };

  return (
    <div className="min-h-screen bg-background flex flex-col animate-in slide-in-from-right duration-300">
      
      {/* Header */}
      <header className="sticky top-0 z-30 bg-background/95 backdrop-blur p-4 pb-2 border-b border-white/5 flex items-center justify-between">
        <button onClick={onBack} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft className="text-white" />
        </button>
        <h1 className="font-bold text-lg text-center flex-1">{isNewEvent ? 'Nuovo Evento' : 'Dettaglio Evento'}</h1>
        <div className="w-10"></div>
      </header>

      {/* Tabs */}
      <div className="flex px-4 pt-4 border-b border-white/5 bg-background z-20">
          <button 
            onClick={() => setActiveTab('info')}
            className={`flex-1 pb-3 text-xs font-bold uppercase tracking-wider border-b-2 transition-colors ${activeTab === 'info' ? 'border-secondary text-white' : 'border-transparent text-gray-500'}`}
          >
              <Info className="w-4 h-4 mx-auto mb-1" /> Info
          </button>
          {showTechnicalTab && (
              <button 
                onClick={() => setActiveTab('technical')}
                className={`flex-1 pb-3 text-xs font-bold uppercase tracking-wider border-b-2 transition-colors ${activeTab === 'technical' ? 'border-secondary text-white' : 'border-transparent text-gray-500'}`}
              >
                  <Activity className="w-4 h-4 mx-auto mb-1" /> Tecnica
              </button>
          )}
          <button 
            onClick={() => setActiveTab('attendees')}
            className={`flex-1 pb-3 text-xs font-bold uppercase tracking-wider border-b-2 transition-colors ${activeTab === 'attendees' ? 'border-secondary text-white' : 'border-transparent text-gray-500'}`}
          >
              <Users className="w-4 h-4 mx-auto mb-1" /> Atleti
          </button>
      </div>

      {/* Content */}
      <main className="flex-1 overflow-y-auto p-4 space-y-6 pb-24">
          {activeTab === 'info' && (
              <div className="space-y-4 animate-in fade-in slide-in-from-left-4">
                   <div className="flex bg-white/5 p-1 rounded-xl">
                      <button 
                        onClick={() => setEditedEvent({...editedEvent, type: 'training'})}
                        className={`flex-1 py-3 rounded-lg text-sm font-bold flex items-center justify-center gap-2 transition-all ${editedEvent.type === 'training' ? 'bg-secondary text-white shadow-lg' : 'text-gray-400'}`}
                      >
                          <Activity className="w-4 h-4" /> Training
                      </button>
                      <button 
                        onClick={() => setEditedEvent({...editedEvent, type: 'match'})}
                        className={`flex-1 py-3 rounded-lg text-sm font-bold flex items-center justify-center gap-2 transition-all ${editedEvent.type === 'match' ? 'bg-orange-500 text-white shadow-lg' : 'text-gray-400'}`}
                      >
                          <Trophy className="w-4 h-4" /> Match
                      </button>
                  </div>

                  <div className="space-y-1">
                      <label className="text-[10px] font-bold uppercase text-gray-500">Tipo Attività</label>
                      <div className="flex bg-white/5 p-1 rounded-xl">
                          <button 
                            type="button"
                            onClick={() => setEditedEvent({...editedEvent, sportCategory: 'ski'})}
                            className={`flex-1 py-3 rounded-lg text-sm font-bold flex items-center justify-center gap-2 transition-all ${editedEvent.sportCategory === 'ski' ? 'bg-secondary text-white shadow-lg' : 'text-gray-400'}`}
                          >
                              <Snowflake className="w-4 h-4" /> Sci
                          </button>
                          <button 
                            type="button"
                            onClick={() => setEditedEvent({...editedEvent, sportCategory: 'dryland'})}
                            className={`flex-1 py-3 rounded-lg text-sm font-bold flex items-center justify-center gap-2 transition-all ${editedEvent.sportCategory === 'dryland' ? 'bg-amber-500 text-white shadow-lg' : 'text-gray-400'}`}
                          >
                              <Dumbbell className="w-4 h-4" /> Atletico / Altro
                          </button>
                      </div>
                  </div>

                  {editedEvent.sportCategory === 'ski' && !isPast && (
                      <div className="space-y-2">
                          <label className="text-[10px] font-bold uppercase text-gray-500">Specialità Sci</label>
                          <div className="flex gap-2">
                              {['SL', 'GS', 'SG', 'DH', 'CL'].map(s => (
                                  <button 
                                    key={s}
                                    type="button"
                                    onClick={() => toggleSpecialty(s)}
                                    className={`flex-1 py-2 rounded-lg text-xs font-bold border ${editedEvent.technicalDetails?.specialties.includes(s) ? 'bg-secondary border-secondary text-white' : 'bg-surface border-white/10 text-gray-500'}`}
                                  >
                                      {s}
                                  </button>
                              ))}
                          </div>
                      </div>
                  )}

                  {editedEvent.sportCategory === 'dryland' && (
                      <div className="space-y-1">
                          <label className="text-[10px] font-bold uppercase text-gray-500">Specialità Atletica / Altro</label>
                          <input 
                            type="text" 
                            value={editedEvent.drylandSpecialty || ''}
                            onChange={e => setEditedEvent({...editedEvent, drylandSpecialty: e.target.value})}
                            className="w-full bg-surface border border-white/10 rounded-xl p-3 text-white focus:ring-1 focus:ring-secondary text-sm"
                            placeholder="Es. Forza esplosiva, Corsa, Circuit training..."
                          />
                      </div>
                  )}

                  <div className="space-y-1">
                      <label className="text-[10px] font-bold uppercase text-gray-500">Titolo</label>
                      <input 
                        type="text" 
                        value={editedEvent.title}
                        onChange={e => setEditedEvent({...editedEvent, title: e.target.value})}
                        className="w-full bg-surface border border-white/10 rounded-xl p-3 text-white focus:ring-1 focus:ring-secondary"
                        placeholder="Es. Allenamento Gigante"
                      />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                      <div className="space-y-1">
                          <label className="text-[10px] font-bold uppercase text-gray-500">Data</label>
                          <input 
                            type="date" 
                            value={editedEvent.date}
                            onChange={e => setEditedEvent({...editedEvent, date: e.target.value})}
                            className="w-full bg-surface border border-white/10 rounded-xl p-3 text-white text-sm"
                          />
                      </div>
                      <div className="space-y-1">
                          <label className="text-[10px] font-bold uppercase text-gray-500">Orario</label>
                          <div className="flex gap-2">
                              <input 
                                type="time" 
                                value={editedEvent.startTime}
                                onChange={e => setEditedEvent({...editedEvent, startTime: e.target.value})}
                                className="w-full bg-surface border border-white/10 rounded-xl p-3 text-white text-sm"
                              />
                              <input 
                                type="time" 
                                value={editedEvent.endTime}
                                onChange={e => setEditedEvent({...editedEvent, endTime: e.target.value})}
                                className="w-full bg-surface border border-white/10 rounded-xl p-3 text-white text-sm"
                              />
                          </div>
                      </div>
                  </div>

                  <div className="space-y-1">
                      <label className="text-[10px] font-bold uppercase text-gray-500">Team</label>
                      <select 
                          value={editedEvent.teamId}
                          onChange={e => setEditedEvent({...editedEvent, teamId: e.target.value})}
                          className="w-full bg-surface border border-white/10 rounded-xl p-3 text-white appearance-none focus:ring-1 focus:ring-secondary"
                      >
                          {teams.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
                      </select>
                  </div>

                  <div className="space-y-1">
                      <label className="text-[10px] font-bold uppercase text-gray-500">Luogo</label>
                      <input 
                          type="text" 
                          value={editedEvent.location || ''}
                          onChange={e => setEditedEvent({...editedEvent, location: e.target.value})}
                          className="w-full bg-surface border border-white/10 rounded-xl p-3 text-white text-sm"
                          placeholder="Pista / Palestra"
                      />
                  </div>
              </div>
          )}

          {activeTab === 'technical' && editedEvent.technicalDetails && (
              <div className="space-y-5 animate-in fade-in slide-in-from-left-4">
                  <div className="grid grid-cols-2 gap-3">
                      <div className="space-y-1">
                          <label className="text-[10px] font-bold uppercase text-gray-500">Neve</label>
                          <select 
                              value={editedEvent.technicalDetails.snowCondition}
                              onChange={e => setEditedEvent({...editedEvent, technicalDetails: {...editedEvent.technicalDetails!, snowCondition: e.target.value}})}
                              className="w-full bg-surface border border-white/10 rounded-xl p-3 text-sm text-white appearance-none"
                          >
                              <option value="">Seleziona...</option>
                              <option value="hard">Compatta/Dura</option>
                              <option value="icy">Ghiacciata</option>
                              <option value="soft">Molle</option>
                              <option value="powder">Fresca</option>
                          </select>
                      </div>
                      <div className="space-y-1">
                          <label className="text-[10px] font-bold uppercase text-gray-500">Meteo</label>
                          <select 
                              value={editedEvent.technicalDetails.weatherCondition}
                              onChange={e => setEditedEvent({...editedEvent, technicalDetails: {...editedEvent.technicalDetails!, weatherCondition: e.target.value}})}
                              className="w-full bg-surface border border-white/10 rounded-xl p-3 text-sm text-white appearance-none"
                          >
                              <option value="">Seleziona...</option>
                              <option value="sunny">Sole</option>
                              <option value="cloudy">Nuvoloso</option>
                              <option value="snowing">Neve</option>
                              <option value="foggy">Nebbia</option>
                          </select>
                      </div>
                  </div>

                  <div className="space-y-2">
                      <label className="text-[10px] font-bold uppercase text-gray-500">Specialità</label>
                      <div className="flex gap-2">
                          {['SL', 'GS', 'SG', 'DH', 'CL'].map(s => (
                              <button 
                                key={s}
                                onClick={() => toggleSpecialty(s)}
                                className={`flex-1 py-2 rounded-lg text-xs font-bold border ${editedEvent.technicalDetails?.specialties.includes(s) ? 'bg-secondary border-secondary text-white' : 'bg-surface border-white/10 text-gray-500'}`}
                              >
                                  {s}
                              </button>
                          ))}
                      </div>
                  </div>

                  <div className="space-y-4">
                      <div className="bg-surface/50 border border-white/5 rounded-xl p-3">
                          <div className="flex items-center gap-2 mb-2 text-primary">
                              <Activity className="w-4 h-4" />
                              <span className="text-xs font-bold uppercase">Campo Libero</span>
                          </div>
                          <div className="grid grid-cols-2 gap-3">
                              <div>
                                  <label className="text-[9px] uppercase font-bold text-gray-500">Giri</label>
                                  <input type="number" placeholder="0" className="w-full bg-black/20 rounded-lg p-2 text-sm text-white" 
                                    value={editedEvent.technicalDetails.freeSkiing.laps}
                                    onChange={e => setEditedEvent({...editedEvent, technicalDetails: {...editedEvent.technicalDetails!, freeSkiing: {...editedEvent.technicalDetails!.freeSkiing, laps: e.target.value}}})}
                                  />
                              </div>
                              <div>
                                  <label className="text-[9px] uppercase font-bold text-gray-500">Cambi/Giro</label>
                                  <input type="number" placeholder="0" className="w-full bg-black/20 rounded-lg p-2 text-sm text-white" 
                                    value={editedEvent.technicalDetails.freeSkiing.changes}
                                    onChange={e => setEditedEvent({...editedEvent, technicalDetails: {...editedEvent.technicalDetails!, freeSkiing: {...editedEvent.technicalDetails!.freeSkiing, changes: e.target.value}}})}
                                  />
                              </div>
                          </div>
                      </div>

                      <div className="bg-surface/50 border border-white/5 rounded-xl p-3">
                          <div className="flex items-center gap-2 mb-2 text-secondary">
                              <Zap className="w-4 h-4" />
                              <span className="text-xs font-bold uppercase">Pali (Tracciato)</span>
                          </div>
                          <div className="grid grid-cols-2 gap-3">
                              <div>
                                  <label className="text-[9px] uppercase font-bold text-gray-500">Giri</label>
                                  <input type="number" placeholder="0" className="w-full bg-black/20 rounded-lg p-2 text-sm text-white" 
                                    value={editedEvent.technicalDetails.gatedSkiing.laps}
                                    onChange={e => setEditedEvent({...editedEvent, technicalDetails: {...editedEvent.technicalDetails!, gatedSkiing: {...editedEvent.technicalDetails!.gatedSkiing, laps: e.target.value}}})}
                                  />
                              </div>
                              <div>
                                  <label className="text-[9px] uppercase font-bold text-gray-500">Porte/Giro</label>
                                  <input type="number" placeholder="0" className="w-full bg-black/20 rounded-lg p-2 text-sm text-white" 
                                    value={editedEvent.technicalDetails.gatedSkiing.changes}
                                    onChange={e => setEditedEvent({...editedEvent, technicalDetails: {...editedEvent.technicalDetails!, gatedSkiing: {...editedEvent.technicalDetails!.gatedSkiing, changes: e.target.value}}})}
                                  />
                              </div>
                          </div>
                      </div>
                  </div>
              </div>
          )}

          {activeTab === 'attendees' && editedEvent.attendees && (
              <div className="space-y-4 animate-in fade-in slide-in-from-left-4">
                  <div className="sticky top-0 bg-background z-10 pb-2 space-y-3">
                      <div className="relative">
                          <Search className="absolute left-3 top-2.5 w-4 h-4 text-gray-500" />
                          <input 
                              type="text" 
                              placeholder="Cerca atleta..." 
                              value={attendeeSearch}
                              onChange={(e) => setAttendeeSearch(e.target.value)}
                              className="w-full bg-black/20 border border-white/10 rounded-xl py-2 pl-9 pr-4 text-sm text-white focus:ring-1 focus:ring-secondary"
                          />
                      </div>
                      <button 
                          onClick={handleToggleSelectAll}
                          className="text-xs font-bold text-secondary uppercase flex items-center gap-1.5 px-1 hover:text-white transition-colors"
                      >
                          {getFilteredAttendees().length > 0 && getFilteredAttendees().every(a => a.isPresent) 
                            ? <CheckSquare className="w-4 h-4" /> 
                            : <Square className="w-4 h-4" />
                          }
                          {getFilteredAttendees().length > 0 && getFilteredAttendees().every(a => a.isPresent) ? 'Deseleziona Tutti' : 'Seleziona Tutti'}
                      </button>
                  </div>

                  <div className="space-y-2">
                      {getFilteredAttendees().map(athlete => (
                          <div key={athlete.id} className={`flex items-center justify-between p-3 rounded-xl border transition-all ${athlete.isPresent ? 'bg-secondary/10 border-secondary/30' : 'bg-surface border-white/5 opacity-60'}`}>
                              <div 
                                className="flex items-center gap-3 flex-1 cursor-pointer"
                                onClick={() => handleAttendeeToggle(athlete.id)}
                              >
                                  {athlete.isPresent ? <CheckSquare className="w-5 h-5 text-secondary" /> : <Square className="w-5 h-5 text-gray-500" />}
                                  <span className="font-bold text-sm">{athlete.name}</span>
                              </div>
                              
                              {athlete.isPresent && isPast && editedEvent.sportCategory !== 'dryland' && (
                                  <div className="flex items-center gap-2">
                                      <label className="text-[9px] uppercase font-bold text-gray-500">Giri</label>
                                      <input 
                                        type="number" 
                                        placeholder={editedEvent.technicalDetails?.gatedSkiing.laps || '0'}
                                        value={athlete.lapsOverride || ''}
                                        onChange={(e) => handleOverrideChange(athlete.id, e.target.value)}
                                        className="w-12 bg-black/20 border border-white/10 rounded text-center text-sm font-bold p-1 focus:ring-1 focus:ring-secondary"
                                      />
                                  </div>
                              )}
                          </div>
                      ))}
                  </div>
              </div>
          )}
      </main>

      {/* Sticky Save Button */}
      <div className="fixed bottom-0 left-0 right-0 p-4 bg-card border-t border-white/10 pb-8 z-30">
          <button 
            onClick={handleSaveClick}
            className="w-full py-4 bg-secondary text-white font-bold rounded-xl shadow-lg shadow-secondary/20 flex items-center justify-center gap-2 hover:bg-sky-500 transition-colors"
          >
              <CheckCircle className="w-5 h-5" /> {isNewEvent ? 'Crea Allenamento' : 'Salva Modifiche'}
          </button>
      </div>
    </div>
  );
};

export default CoachEventDetails;
