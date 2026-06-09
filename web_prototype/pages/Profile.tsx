
import React, { useState, useRef } from 'react';
import { ArrowLeft, Edit, Verified, Monitor, Ruler, Heart, Mail, Calendar, Bell, Watch, ChevronRight, Check, Image, Camera, Globe, ToggleLeft, ToggleRight, Bluetooth, Activity, Smartphone, X, Loader2, Link as LinkIcon, Unplug, Battery } from 'lucide-react';
import { ViewState, UserProfile, UnitSystem, Language, ConnectedDevice } from '../types';
import { translations } from '../i18n';

interface Props {
  setView: (view: ViewState) => void;
  userProfile: UserProfile;
  onSave: (profile: UserProfile) => void;
  onLogout: () => void;
  showBackArrow?: boolean; // New prop to optionally hide back button
}

const INTEGRATIONS: { id: ConnectedDevice['provider'], name: string, icon: any, color: string, type: 'api' | 'ble' }[] = [
    { id: 'garmin', name: 'Garmin Connect', icon: Activity, color: '#007cc3', type: 'api' },
    { id: 'whoop', name: 'Whoop', icon: Activity, color: '#ff3b30', type: 'api' },
    { id: 'polar', name: 'Polar Flow / BLE', icon: Heart, color: '#e60012', type: 'ble' },
    { id: 'apple', name: 'Apple Health', icon: Heart, color: '#ffffff', type: 'api' },
    { id: 'amazfit', name: 'Amazfit / Zepp', icon: Watch, color: '#2ecc71', type: 'api' },
    { id: 'generic', name: 'Standard BLE Monitor', icon: Bluetooth, color: '#0070f3', type: 'ble' },
];

const Profile: React.FC<Props> = ({ setView, userProfile, onSave, onLogout, showBackArrow = true }) => {
  // Local state for "Draft" mode
  const [draftProfile, setDraftProfile] = useState<UserProfile>(userProfile);
  const [showUnitSelector, setShowUnitSelector] = useState(false);
  const [showLangSelector, setShowLangSelector] = useState(false);
  
  // Device Management State
  const [showDeviceModal, setShowDeviceModal] = useState(false);
  const [connectingProvider, setConnectingProvider] = useState<string | null>(null);
  const isCoach = draftProfile.role === 'coach';

  // Use the CURRENT profile language for the UI until saved
  const t = translations[userProfile.language];

  // States for Image Upload Permission Flow
  const [showPermissionPopup, setShowPermissionPopup] = useState(false);
  const [hasGalleryPermission, setHasGalleryPermission] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Helper for conversions purely for display within inputs
  const toDisplayHeight = (cm: number, system: UnitSystem) => {
    return system === 'metric' ? Math.round(cm) : Math.round(cm / 30.48 * 10) / 10; // ft
  };
  
  const toDisplayWeight = (kg: number, system: UnitSystem) => {
    return system === 'metric' ? kg : Math.round(kg * 2.20462 * 10) / 10;
  };

  // Handlers
  const handleUnitChange = (system: UnitSystem) => {
    setDraftProfile({ ...draftProfile, unitSystem: system });
    setShowUnitSelector(false);
  };

  const handleLanguageChange = (lang: Language) => {
    setDraftProfile({ ...draftProfile, language: lang });
    setShowLangSelector(false);
  };

  const handleHeightChange = (val: string) => {
     const num = parseFloat(val);
     if (isNaN(num)) return;
     // Store internally as CM
     const newCm = draftProfile.unitSystem === 'metric' ? num : num * 30.48;
     setDraftProfile({ ...draftProfile, height: newCm });
  };

  const handleMaxHrChange = (val: string) => {
    setDraftProfile({ ...draftProfile, maxHr: parseInt(val) || 0 });
  };
  
  const handleNotificationToggle = () => {
    const newState = !draftProfile.notificationsEnabled;
    setDraftProfile({ ...draftProfile, notificationsEnabled: newState });
    
    // If turning on, request permission if not already granted
    if (newState) {
        if ('Notification' in window && Notification.permission !== 'granted') {
            Notification.requestPermission();
        }
    }
  };

  // --- Device Management Logic ---
  
  const connectBLEDevice = async (provider: 'polar' | 'generic') => {
      // Check if browser supports Web Bluetooth
      // @ts-ignore
      if (!navigator.bluetooth) {
          alert("Web Bluetooth not supported on this browser (Try Chrome, Edge, or Bluefy on iOS).");
          setConnectingProvider(null);
          return;
      }

      try {
          // @ts-ignore
          const device = await navigator.bluetooth.requestDevice({
              filters: [{ services: ['heart_rate'] }],
              optionalServices: ['battery_service']
          });

          if (device) {
              // Note: In a real app we would connect to GATT server here. 
              // For now, we simulate success after selection.
              const newDevice: ConnectedDevice = {
                  id: device.id,
                  name: device.name || 'Heart Rate Monitor',
                  type: 'ble',
                  provider: provider,
                  status: 'connected',
                  batteryLevel: 88,
                  lastSync: 'Now'
              };
              setDraftProfile(prev => ({
                  ...prev,
                  connectedDevices: [...prev.connectedDevices, newDevice]
              }));
          }
      } catch (error) {
          console.error("Bluetooth Error:", error);
      } finally {
          setConnectingProvider(null);
      }
  };

  const connectAPIDevice = (provider: ConnectedDevice['provider']) => {
      // Simulate OAuth flow
      setTimeout(() => {
          const newDevice: ConnectedDevice = {
              id: `${provider}-id`,
              name: provider === 'garmin' ? 'Forerunner 965' : provider === 'whoop' ? 'Whoop 4.0' : provider === 'apple' ? 'Apple Watch' : 'Amazfit GTR',
              type: 'api',
              provider: provider,
              status: 'connected',
              lastSync: 'Just now'
          };
          setDraftProfile(prev => ({
              ...prev,
              connectedDevices: [...prev.connectedDevices, newDevice]
          }));
          setConnectingProvider(null);
      }, 1500);
  };

  const handleConnectDevice = (provider: ConnectedDevice['provider'], type: 'api' | 'ble') => {
      setConnectingProvider(provider);
      if (type === 'ble') {
          connectBLEDevice(provider as 'polar' | 'generic');
      } else {
          connectAPIDevice(provider);
      }
  };

  const handleDisconnectDevice = (deviceId: string) => {
      setDraftProfile(prev => ({
          ...prev,
          connectedDevices: prev.connectedDevices.filter(d => d.id !== deviceId)
      }));
  };

  // Image Upload Handlers
  const handleProfileImageClick = () => {
    if (hasGalleryPermission) {
        fileInputRef.current?.click();
    } else {
        setShowPermissionPopup(true);
    }
  };

  const grantPermission = () => {
    setHasGalleryPermission(true);
    setShowPermissionPopup(false);
    // Slight delay to allow modal to close before system dialog opens
    setTimeout(() => {
        fileInputRef.current?.click();
    }, 200);
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
        const reader = new FileReader();
        reader.onloadend = () => {
            setDraftProfile({ ...draftProfile, avatarUrl: reader.result as string });
        };
        reader.readAsDataURL(file);
    }
  };

  return (
    <div className="pb-24 min-h-screen bg-background relative">
        {/* Hidden File Input */}
        <input 
            type="file" 
            ref={fileInputRef} 
            onChange={handleFileChange} 
            accept="image/*" 
            className="hidden" 
        />

        {/* Device Management Modal */}
        {!isCoach && showDeviceModal && (
            <div className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center">
                <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => setShowDeviceModal(false)}></div>
                <div className="bg-card w-full max-w-md h-[80vh] sm:h-auto sm:rounded-2xl rounded-t-3xl border-t sm:border border-white/10 relative z-10 animate-in slide-in-from-bottom duration-300 flex flex-col">
                    <div className="p-4 border-b border-white/5 flex justify-between items-center">
                        <h3 className="font-bold text-lg">Dispositivi Connessi</h3>
                        <button onClick={() => setShowDeviceModal(false)} className="p-2 hover:bg-white/10 rounded-full">
                            <X className="w-5 h-5 text-gray-400" />
                        </button>
                    </div>
                    
                    <div className="flex-1 overflow-y-auto p-4 space-y-6">
                        
                        {/* Connected List */}
                        {draftProfile.connectedDevices.length > 0 && (
                            <div className="space-y-3">
                                <h4 className="text-xs font-bold uppercase text-gray-500 tracking-wider">I tuoi dispositivi</h4>
                                {draftProfile.connectedDevices.map(device => {
                                    const integration = INTEGRATIONS.find(i => i.id === device.provider) || INTEGRATIONS[5];
                                    return (
                                        <div key={device.id} className="bg-surface border border-white/5 p-4 rounded-xl flex items-center justify-between group">
                                            <div className="flex items-center gap-3">
                                                <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{backgroundColor: `${integration.color}20`, color: integration.color}}>
                                                    <integration.icon className="w-5 h-5" />
                                                </div>
                                                <div>
                                                    <p className="font-bold text-sm">{device.name}</p>
                                                    <div className="flex items-center gap-2 text-xs text-gray-400">
                                                        <span className="flex items-center gap-1 text-green-500"><span className="w-1.5 h-1.5 rounded-full bg-green-500"></span> Connesso</span>
                                                        {device.batteryLevel && (
                                                            <span className="flex items-center gap-1"><Battery className="w-3 h-3" /> {device.batteryLevel}%</span>
                                                        )}
                                                    </div>
                                                </div>
                                            </div>
                                            <button 
                                                onClick={() => handleDisconnectDevice(device.id)}
                                                className="text-gray-500 hover:text-red-500 p-2 transition bg-white/5 rounded-lg"
                                            >
                                                <Unplug className="w-4 h-4" />
                                            </button>
                                        </div>
                                    );
                                })}
                            </div>
                        )}

                        {/* Available Integrations */}
                        <div className="space-y-3">
                            <h4 className="text-xs font-bold uppercase text-gray-500 tracking-wider">Disponibili</h4>
                            {INTEGRATIONS.filter(i => !draftProfile.connectedDevices.some(d => d.provider === i.id)).map(integration => (
                                <button 
                                    key={integration.id}
                                    disabled={connectingProvider !== null}
                                    onClick={() => handleConnectDevice(integration.id, integration.type)}
                                    className="w-full bg-card border border-white/5 p-4 rounded-xl flex items-center justify-between hover:bg-white/5 active:scale-[0.99] transition disabled:opacity-50"
                                >
                                    <div className="flex items-center gap-3">
                                        <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{backgroundColor: `${integration.color}20`, color: integration.color}}>
                                            <integration.icon className="w-5 h-5" />
                                        </div>
                                        <div className="text-left">
                                            <p className="font-bold text-sm">{integration.name}</p>
                                            <p className="text-xs text-gray-500">{integration.type === 'ble' ? 'Connessione Diretta Bluetooth' : 'Sincronizzazione Cloud API'}</p>
                                        </div>
                                    </div>
                                    {connectingProvider === integration.id ? (
                                        <Loader2 className="w-5 h-5 animate-spin text-secondary" />
                                    ) : (
                                        <LinkIcon className="w-5 h-5 text-gray-600" />
                                    )}
                                </button>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        )}

        {/* Permission Popup Modal */}
        {showPermissionPopup && (
            <div className="fixed inset-0 z-[60] flex items-center justify-center p-4">
                <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowPermissionPopup(false)}></div>
                <div className="bg-card border border-white/10 p-6 rounded-2xl w-full max-w-sm relative z-10 shadow-2xl animate-in zoom-in-95 duration-200">
                    <div className="w-12 h-12 bg-secondary/20 rounded-full flex items-center justify-center mb-4 mx-auto">
                        <Image className="w-6 h-6 text-secondary" />
                    </div>
                    <h3 className="text-lg font-bold text-center mb-2">{t.allowAccess}</h3>
                    <p className="text-gray-400 text-sm text-center mb-6 leading-relaxed">
                        {t.allowAccessDesc}
                    </p>
                    <div className="flex flex-col gap-3">
                        <button 
                            onClick={grantPermission}
                            className="w-full py-3 bg-secondary text-white font-bold rounded-xl text-sm hover:bg-sky-500 transition"
                        >
                            {t.allow}
                        </button>
                        <button 
                            onClick={() => setShowPermissionPopup(false)}
                            className="w-full py-3 bg-white/5 text-gray-400 font-bold rounded-xl text-sm hover:bg-white/10 transition"
                        >
                            {t.dontAllow}
                        </button>
                    </div>
                </div>
            </div>
        )}

        <header className="sticky top-0 z-50 flex items-center bg-background/95 backdrop-blur p-4 pb-2 border-b border-white/5">
            {showBackArrow ? (
                <button onClick={() => setView('home')} className="w-10 h-10 flex items-center justify-center rounded-full active:bg-white/10">
                    <ArrowLeft className="text-white" />
                </button>
            ) : (
                <div className="w-10"></div>
            )}
            <h2 className="flex-1 text-center font-bold text-lg">{t.profileSettings}</h2>
            <button 
              onClick={() => onSave(draftProfile)}
              className="text-secondary font-bold text-base px-2 active:scale-95 transition-transform"
            >
              {t.save}
            </button>
        </header>

        <section className="flex flex-col items-center pt-8 px-4">
            <div 
                className="relative cursor-pointer group active:scale-95 transition-transform"
                onClick={handleProfileImageClick}
            >
                <div className="w-28 h-28 rounded-full bg-cover bg-center border-2 border-card shadow-xl overflow-hidden relative">
                    {/* Image */}
                    <div 
                        className="absolute inset-0 bg-cover bg-center"
                        style={{backgroundImage: `url("${draftProfile.avatarUrl}")`}}
                    ></div>
                    {/* Overlay on Hover */}
                    <div className="absolute inset-0 bg-black/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                         <Camera className="w-6 h-6 text-white" />
                    </div>
                </div>
                <div className="absolute bottom-0 right-0 bg-secondary p-1.5 rounded-full border-2 border-background">
                    <Edit className="w-4 h-4 text-white" />
                </div>
            </div>
            <h1 className="text-2xl font-bold mt-4">{draftProfile.firstName} {draftProfile.lastName}</h1>
            <div className="flex items-center gap-2 mt-1">
                <Verified className="w-4 h-4 text-secondary" />
                <span className="text-gray-400 text-sm font-bold uppercase tracking-wider">{t.proMember}</span>
            </div>
        </section>

        <section className="px-4 py-6">
            <div className="flex justify-between items-end mb-3">
                <h3 className="font-bold text-lg">{t.vitals}</h3>
            </div>
            <div className="grid grid-cols-3 gap-3">
                {/* Weight - Read Only */}
                <div className="bg-card border border-white/5 rounded-xl p-4 flex flex-col gap-1 opacity-75">
                    <div className="flex items-center gap-1 text-gray-400">
                        <Monitor className="w-4 h-4" />
                        <span className="text-xs font-bold uppercase">{t.weight}</span>
                    </div>
                    <div className="flex items-baseline gap-1">
                        <span className="text-xl font-bold">{toDisplayWeight(draftProfile.weight, draftProfile.unitSystem)}</span>
                        <span className="text-sm font-normal text-gray-500">{draftProfile.unitSystem === 'metric' ? 'kg' : 'lbs'}</span>
                    </div>
                </div>

                {/* Height - Editable */}
                <div className="bg-card border border-white/5 rounded-xl p-4 flex flex-col gap-1 relative group focus-within:border-secondary transition-colors">
                    <div className="flex items-center gap-1 text-gray-400">
                        <Ruler className="w-4 h-4" />
                        <span className="text-xs font-bold uppercase">{t.height}</span>
                    </div>
                    <div className="flex items-baseline gap-1">
                         <input 
                            type="number" 
                            value={toDisplayHeight(draftProfile.height, draftProfile.unitSystem)}
                            onChange={(e) => handleHeightChange(e.target.value)}
                            className="text-xl font-bold bg-transparent border-none p-0 w-full focus:ring-0 appearance-none"
                         />
                        <span className="text-sm font-normal text-gray-500">{draftProfile.unitSystem === 'metric' ? 'cm' : 'ft'}</span>
                    </div>
                    <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                         <Edit className="w-3 h-3 text-gray-500" />
                    </div>
                </div>

                {/* Max HR - Editable */}
                <div className="bg-card border border-white/5 rounded-xl p-4 flex flex-col gap-1 relative group focus-within:border-secondary transition-colors">
                    <div className="flex items-center gap-1 text-gray-400">
                        <Heart className="w-4 h-4" />
                        <span className="text-xs font-bold uppercase">{t.maxHr}</span>
                    </div>
                     <div className="flex items-baseline gap-1">
                         <input 
                            type="number" 
                            value={draftProfile.maxHr}
                            onChange={(e) => handleMaxHrChange(e.target.value)}
                            className="text-xl font-bold bg-transparent border-none p-0 w-full focus:ring-0 appearance-none"
                         />
                        <span className="text-sm font-normal text-gray-500">bpm</span>
                    </div>
                     <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                         <Edit className="w-3 h-3 text-gray-500" />
                    </div>
                </div>
            </div>
        </section>

        <section className="px-4 pb-6 space-y-4">
            <h3 className="font-bold text-lg">{t.personalDetails}</h3>
            <div className="flex gap-4">
                <div className="flex-1">
                    <label className="text-xs font-bold text-gray-500 uppercase mb-1.5 block">{t.firstName}</label>
                    <input 
                      type="text" 
                      value={draftProfile.firstName} 
                      onChange={(e) => setDraftProfile({...draftProfile, firstName: e.target.value})}
                      className="w-full bg-card border-none rounded-lg text-white p-3 focus:ring-1 focus:ring-secondary" 
                    />
                </div>
                <div className="flex-1">
                    <label className="text-xs font-bold text-gray-500 uppercase mb-1.5 block">{t.lastName}</label>
                    <input 
                      type="text" 
                      value={draftProfile.lastName} 
                      onChange={(e) => setDraftProfile({...draftProfile, lastName: e.target.value})}
                      className="w-full bg-card border-none rounded-lg text-white p-3 focus:ring-1 focus:ring-secondary" 
                    />
                </div>
            </div>
            <div>
                 <label className="text-xs font-bold text-gray-500 uppercase mb-1.5 block">{t.email}</label>
                 <div className="relative">
                    <Mail className="absolute left-3 top-3.5 w-5 h-5 text-gray-500" />
                    <input type="email" value={draftProfile.email} onChange={(e) => setDraftProfile({...draftProfile, email: e.target.value})} className="w-full bg-card border-none rounded-lg text-white p-3 pl-10 focus:ring-1 focus:ring-secondary" />
                 </div>
            </div>
             <div>
                 <label className="text-xs font-bold text-gray-500 uppercase mb-1.5 block">{t.dob}</label>
                 <div className="relative">
                    <Calendar className="absolute left-3 top-3.5 w-5 h-5 text-gray-500" />
                    <input type="text" value={draftProfile.birthDate} onChange={(e) => setDraftProfile({...draftProfile, birthDate: e.target.value})} className="w-full bg-card border-none rounded-lg text-white p-3 pl-10 focus:ring-1 focus:ring-secondary" />
                 </div>
            </div>
        </section>

        <section className="px-4 pb-8">
            <h3 className="font-bold text-lg mb-4">{t.appPreferences}</h3>
            <div className="bg-card rounded-xl border border-white/5 overflow-hidden">
                <div 
                    onClick={handleNotificationToggle}
                    className="flex items-center justify-between p-4 border-b border-white/5 cursor-pointer hover:bg-white/5"
                >
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-secondary/10 flex items-center justify-center text-secondary"><Bell className="w-4 h-4" /></div>
                        <span className="font-medium">{t.notifications}</span>
                    </div>
                    {draftProfile.notificationsEnabled ? (
                        <ToggleRight className="w-8 h-8 text-secondary transition-colors" />
                    ) : (
                        <ToggleLeft className="w-8 h-8 text-gray-500 transition-colors" />
                    )}
                </div>
                
                {/* Units Selector */}
                <div onClick={() => setShowUnitSelector(!showUnitSelector)} className="flex items-center justify-between p-4 border-b border-white/5 cursor-pointer hover:bg-white/5">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-secondary/10 flex items-center justify-center text-secondary"><Ruler className="w-4 h-4" /></div>
                        <span className="font-medium">{t.units}</span>
                    </div>
                    <div className="flex items-center gap-2 text-gray-500">
                        <span className="text-sm">{draftProfile.unitSystem === 'metric' ? 'Metric (kg/cm)' : 'Imperial (lbs/ft)'}</span>
                        <ChevronRight className="w-5 h-5" />
                    </div>
                </div>
                {showUnitSelector && (
                    <div className="bg-surface border-b border-white/5 p-2 animate-in slide-in-from-top-2">
                        <button 
                            onClick={() => handleUnitChange('metric')}
                            className={`w-full text-left p-3 rounded-lg text-sm font-medium flex justify-between items-center ${draftProfile.unitSystem === 'metric' ? 'bg-white/10 text-white' : 'text-gray-400'}`}
                        >
                            Metric <span className="text-xs opacity-50">Kg, Cm, Km</span>
                            {draftProfile.unitSystem === 'metric' && <Check className="w-4 h-4 text-secondary" />}
                        </button>
                        <button 
                            onClick={() => handleUnitChange('imperial')}
                            className={`w-full text-left p-3 rounded-lg text-sm font-medium flex justify-between items-center ${draftProfile.unitSystem === 'imperial' ? 'bg-white/10 text-white' : 'text-gray-400'}`}
                        >
                            Imperial <span className="text-xs opacity-50">Lbs, Ft, Miles</span>
                             {draftProfile.unitSystem === 'imperial' && <Check className="w-4 h-4 text-secondary" />}
                        </button>
                    </div>
                )}

                 {/* Language Selector */}
                 <div onClick={() => setShowLangSelector(!showLangSelector)} className="flex items-center justify-between p-4 border-b border-white/5 cursor-pointer hover:bg-white/5">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-secondary/10 flex items-center justify-center text-secondary"><Globe className="w-4 h-4" /></div>
                        <span className="font-medium">{t.language}</span>
                    </div>
                    <div className="flex items-center gap-2 text-gray-500">
                        <span className="text-sm">{draftProfile.language === 'en' ? 'English' : 'Italiano'}</span>
                        <ChevronRight className="w-5 h-5" />
                    </div>
                </div>
                {showLangSelector && (
                    <div className="bg-surface border-b border-white/5 p-2 animate-in slide-in-from-top-2">
                        <button 
                            onClick={() => handleLanguageChange('en')}
                            className={`w-full text-left p-3 rounded-lg text-sm font-medium flex justify-between items-center ${draftProfile.language === 'en' ? 'bg-white/10 text-white' : 'text-gray-400'}`}
                        >
                            English 
                            {draftProfile.language === 'en' && <Check className="w-4 h-4 text-secondary" />}
                        </button>
                        <button 
                            onClick={() => handleLanguageChange('it')}
                            className={`w-full text-left p-3 rounded-lg text-sm font-medium flex justify-between items-center ${draftProfile.language === 'it' ? 'bg-white/10 text-white' : 'text-gray-400'}`}
                        >
                            Italiano
                             {draftProfile.language === 'it' && <Check className="w-4 h-4 text-secondary" />}
                        </button>
                    </div>
                )}

                {!isCoach && (
                    /* Connected Devices - UPDATED */
                    <div onClick={() => setShowDeviceModal(true)} className="flex items-center justify-between p-4 cursor-pointer hover:bg-white/5">
                        <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-secondary/10 flex items-center justify-center text-secondary"><Watch className="w-4 h-4" /></div>
                            <span className="font-medium">{t.connectedDevices}</span>
                        </div>
                         <div className="flex items-center gap-2 text-gray-500">
                            {draftProfile.connectedDevices.length > 0 && <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>}
                            <span className="text-sm">{draftProfile.connectedDevices.length} {t.active}</span>
                            <ChevronRight className="w-5 h-5" />
                        </div>
                    </div>
                )}
            </div>
        </section>
        
        <div className="flex justify-center pb-8">
            <button onClick={onLogout} className="text-red-500 font-bold uppercase text-sm tracking-widest hover:bg-red-500/10 px-4 py-2 rounded-lg transition">{t.logOut}</button>
        </div>
    </div>
  );
};

export default Profile;
