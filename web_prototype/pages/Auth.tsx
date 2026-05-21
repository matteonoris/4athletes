
import React, { useState, useRef } from 'react';
import { Mail, Lock, ArrowRight, User, Users, Calendar, Ruler, Monitor, Heart, ChevronLeft, Camera, Image, Check } from 'lucide-react';
import { UserRole, UserProfile } from '../types';
import { translations } from '../i18n';

interface Props {
  onRegister: (profile: UserProfile) => void;
  onLogin: () => void;
}

type SignupStep = 'role' | 'auth-choice' | 'account' | 'personal' | 'photo' | 'physical';

const GoogleIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.66l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.47 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
  </svg>
);

const AppleIcon = () => (
  <svg width="20" height="20" viewBox="0 0 256 315" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
    <path d="M213.803 167.03c.442 47.847 41.733 64.184 42.193 64.374-.343.98-6.555 22.405-21.65 44.413-13.044 19.014-26.556 37.95-47.834 38.344-20.91.383-27.647-12.353-51.573-12.353-23.905 0-31.397 12.01-51.18 12.755-20.155.735-35.63-20.322-48.748-39.208-26.824-38.64-47.33-109.13-19.818-156.883 13.633-23.712 38.076-38.746 64.577-39.124 20.156-.37 39.223 13.565 51.573 13.565 12.333 0 35.807-16.793 60.154-14.332 10.19.421 38.803 4.102 57.214 31.025-1.488.924-34.195 19.957-33.84 59.728M176.388 40.573c10.887-13.212 18.25-31.55 16.242-49.827-15.688.636-34.693 10.45-45.932 23.596-10.076 11.664-18.89 30.345-16.516 48.243 17.514 1.355 35.313-8.8 46.206-22.012"/>
  </svg>
);

const Auth: React.FC<Props> = ({ onRegister, onLogin }) => {
  const [isSignUp, setIsSignUp] = useState(false);
  const [step, setStep] = useState<SignupStep>('role');
  const t = translations['it'];

  // Registration State
  const [role, setRole] = useState<UserRole>('athlete');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [dob, setDob] = useState('');
  const [weight, setWeight] = useState('75');
  const [height, setHeight] = useState('180');
  const [maxHr, setMaxHr] = useState('190');
  const [avatarUrl, setAvatarUrl] = useState('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&h=400&fit=crop');

  // Permission Modal State
  const [showPermissionPopup, setShowPermissionPopup] = useState(false);
  const [hasGalleryPermission, setHasGalleryPermission] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFinishRegistration = () => {
    const profile: UserProfile = {
      firstName,
      lastName,
      email,
      birthDate: dob,
      role,
      weight: parseFloat(weight),
      height: parseFloat(height),
      maxHr: parseInt(maxHr),
      unitSystem: 'metric',
      language: 'it',
      avatarUrl: avatarUrl,
      notificationsEnabled: true, // Defaulting to true for new registrations
      connectedDevices: [],
    };
    onRegister(profile);
  };

  const handleSocialAction = () => {
    if (!isSignUp) {
        onLogin();
    } else {
        // Social Signup: Force personal detail collection after role selection
        setStep('personal');
    }
  };

  const nextStep = () => {
    if (step === 'role') setStep('auth-choice');
    else if (step === 'auth-choice') setStep('account'); 
    else if (step === 'account') setStep('personal');
    else if (step === 'personal') setStep('photo');
    else if (step === 'photo') {
        if (role === 'athlete') setStep('physical');
        else handleFinishRegistration();
    }
    else if (step === 'physical') handleFinishRegistration();
  };

  const prevStep = () => {
    if (step === 'auth-choice') setStep('role');
    else if (step === 'account') setStep('auth-choice');
    else if (step === 'personal') setStep('auth-choice');
    else if (step === 'photo') setStep('personal');
    else if (step === 'physical') setStep('photo');
  };

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
    setTimeout(() => {
        fileInputRef.current?.click();
    }, 200);
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
        const reader = new FileReader();
        reader.onloadend = () => {
            setAvatarUrl(reader.result as string);
        };
        reader.readAsDataURL(file);
    }
  };

  if (!isSignUp) {
    return (
      <div className="min-h-screen bg-background flex flex-col relative overflow-hidden font-sans">
        <div className="absolute top-0 left-0 w-full h-1/2 bg-gradient-to-b from-secondary/10 to-transparent z-0"></div>
        <div className="flex-1 flex flex-col justify-center px-6 relative z-10">
          <div className="mb-10 text-center">
              <div className="w-20 h-20 bg-gradient-to-tr from-secondary to-primary rounded-3xl mx-auto mb-6 shadow-xl shadow-secondary/20 flex items-center justify-center">
                  <span className="text-4xl font-black text-background italic">4A</span>
              </div>
              <h1 className="text-3xl font-black tracking-tight mb-2">4ATHLETES</h1>
              <p className="text-gray-400 text-sm">Track, Analyze, and Dominate.</p>
          </div>

          <form onSubmit={(e) => { e.preventDefault(); onLogin(); }} className="space-y-4">
              <div className="relative">
                  <Mail className="absolute left-4 top-3.5 w-5 h-5 text-gray-500" />
                  <input type="email" placeholder="Email" className="w-full bg-card border border-white/5 rounded-2xl py-3.5 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary transition-all outline-none" />
              </div>
              <div className="relative">
                  <Lock className="absolute left-4 top-3.5 w-5 h-5 text-gray-500" />
                  <input type="password" placeholder="Password" className="w-full bg-card border border-white/5 rounded-2xl py-3.5 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary transition-all outline-none" />
              </div>
              <button type="submit" className="w-full bg-secondary text-white h-14 rounded-2xl font-bold text-lg shadow-lg shadow-secondary/25 active:scale-[0.98] transition-all flex items-center justify-center gap-2">
                  Accedi <ArrowRight className="w-5 h-5" />
              </button>
          </form>

          <div className="mt-8 flex flex-col items-center gap-4">
              <div className="flex items-center gap-4 w-full text-gray-700">
                  <div className="h-px bg-white/5 flex-1"></div>
                  <span className="text-[10px] font-bold uppercase tracking-widest">oppure</span>
                  <div className="h-px bg-white/5 flex-1"></div>
              </div>

              <div className="grid grid-cols-2 gap-3 w-full">
                  <button 
                    onClick={handleSocialAction}
                    className="flex items-center justify-center gap-2 bg-white text-black h-12 rounded-xl font-bold text-sm hover:bg-gray-100 transition-colors shadow-sm"
                  >
                    <GoogleIcon /> Google
                  </button>
                  <button 
                    onClick={handleSocialAction}
                    className="flex items-center justify-center gap-2 bg-card border border-white/10 text-white h-12 rounded-xl font-bold text-sm hover:bg-white/5 transition-colors shadow-sm"
                  >
                    <AppleIcon /> Apple
                  </button>
              </div>

              <button onClick={() => { setIsSignUp(true); setStep('role'); }} className="text-gray-400 text-sm mt-4">
                  Non hai un account? <span className="text-secondary font-bold">Iscriviti</span>
              </button>
          </div>
        </div>
      </div>
    );
  }

  // Registration Multi-step UI
  return (
    <div className="min-h-screen bg-background flex flex-col p-6 animate-in fade-in duration-500 relative font-sans">
      <input 
          type="file" 
          ref={fileInputRef} 
          onChange={handleFileChange} 
          accept="image/*" 
          className="hidden" 
      />

      {/* Permission Modal */}
      {showPermissionPopup && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
              <div className="absolute inset-0 bg-black/90 backdrop-blur-md" onClick={() => setShowPermissionPopup(false)}></div>
              <div className="bg-card border border-white/10 p-8 rounded-[2rem] w-full max-w-sm relative z-10 shadow-2xl animate-in zoom-in-95 duration-200 text-center">
                  <div className="w-20 h-20 bg-secondary/20 rounded-full flex items-center justify-center mb-6 mx-auto">
                      <Image className="w-10 h-10 text-secondary" />
                  </div>
                  <h3 className="text-2xl font-bold mb-3">{t.allowAccess}</h3>
                  <p className="text-gray-400 text-sm mb-8 leading-relaxed">
                      {t.allowAccessDesc}
                  </p>
                  <div className="flex flex-col gap-3">
                      <button onClick={grantPermission} className="w-full py-4 bg-secondary text-white font-bold rounded-2xl text-base hover:brightness-110 transition shadow-lg shadow-secondary/20">
                          {t.allow}
                      </button>
                      <button onClick={() => setShowPermissionPopup(false)} className="w-full py-4 bg-white/5 text-gray-500 font-bold rounded-2xl text-base hover:bg-white/10 transition">
                          {t.dontAllow}
                      </button>
                  </div>
              </div>
          </div>
      )}

      <header className="flex items-center gap-4 mb-8 pt-4">
          {step !== 'role' && (
              <button onClick={prevStep} className="p-2 bg-white/5 rounded-full hover:bg-white/10 transition">
                  <ChevronLeft className="w-6 h-6" />
              </button>
          )}
          <div className="flex-1">
              <p className="text-xs font-bold text-secondary uppercase tracking-widest mb-0.5">Iscrizione</p>
              <h2 className="text-2xl font-black">
                  {step === 'role' && "Chi sei?"}
                  {step === 'auth-choice' && "Iscriviti con"}
                  {step === 'account' && "Account"}
                  {step === 'personal' && "Chi sei?"}
                  {step === 'photo' && "Foto Profilo"}
                  {step === 'physical' && "Dati Fisici"}
              </h2>
          </div>
          <div className="text-xs font-black text-gray-700 bg-white/5 px-3 py-1.5 rounded-full">
              {step === 'role' ? '1' : step === 'auth-choice' ? '2' : step === 'account' ? '3' : step === 'personal' ? '4' : step === 'photo' ? '5' : '6'}/6
          </div>
      </header>

      <main className="flex-1">
        {step === 'role' && (
            <div className="flex flex-col gap-6 animate-in slide-in-from-bottom-4 duration-300">
                <div className="grid grid-cols-1 gap-4">
                    <button 
                        onClick={() => { setRole('athlete'); nextStep(); }}
                        className="group bg-card border-2 border-white/5 p-8 rounded-[2rem] text-left hover:border-secondary transition-all active:scale-[0.98]"
                    >
                        <div className="w-14 h-14 bg-secondary/10 rounded-2xl flex items-center justify-center mb-6 group-hover:bg-secondary group-hover:text-white transition-all shadow-inner">
                            <User className="w-7 h-7" />
                        </div>
                        <h3 className="text-xl font-bold mb-2">Atleta</h3>
                        <p className="text-sm text-gray-500 leading-relaxed">Traccia i tuoi allenamenti, monitora i progressi e competi con la squadra.</p>
                    </button>
                    <button 
                        onClick={() => { setRole('coach'); nextStep(); }}
                        className="group bg-card border-2 border-white/5 p-8 rounded-[2rem] text-left hover:border-primary transition-all active:scale-[0.98]"
                    >
                        <div className="w-14 h-14 bg-primary/10 rounded-2xl flex items-center justify-center mb-6 group-hover:bg-primary group-hover:text-background transition-all shadow-inner">
                            <Users className="w-7 h-7" />
                        </div>
                        <h3 className="text-xl font-bold mb-2">Allenatore</h3>
                        <p className="text-sm text-gray-500 leading-relaxed">Gestisci i tuoi team, analizza le performance e pianifica le sessioni.</p>
                    </button>
                </div>
            </div>
        )}

        {step === 'auth-choice' && (
            <div className="flex flex-col gap-4 animate-in slide-in-from-right-4 duration-300">
                <button 
                    onClick={() => setStep('account')}
                    className="w-full bg-card border border-white/5 h-18 py-5 rounded-2xl font-bold flex items-center px-6 gap-4 hover:bg-white/5 transition-all shadow-sm active:scale-[0.98]"
                >
                    <div className="p-3 bg-secondary/10 rounded-xl">
                        <Mail className="w-6 h-6 text-secondary" />
                    </div>
                    <span className="text-lg">Email e Password</span>
                </button>
                
                <div className="flex items-center gap-4 py-6 text-gray-700">
                    <div className="h-px bg-white/5 flex-1"></div>
                    <span className="text-[10px] font-bold uppercase tracking-[0.2em]">O SOCIAL</span>
                    <div className="h-px bg-white/5 flex-1"></div>
                </div>

                <div className="grid grid-cols-1 gap-3">
                    <button onClick={handleSocialAction} className="flex items-center justify-center gap-4 bg-white text-black h-18 py-5 rounded-2xl font-bold text-lg hover:brightness-95 transition-all shadow-sm active:scale-[0.98]">
                        <GoogleIcon /> Google
                    </button>
                    <button onClick={handleSocialAction} className="flex items-center justify-center gap-4 bg-card border border-white/10 text-white h-18 py-5 rounded-2xl font-bold text-lg hover:bg-white/5 transition-all shadow-sm active:scale-[0.98]">
                        <AppleIcon /> Apple
                    </button>
                </div>
            </div>
        )}

        {step === 'account' && (
            <div className="space-y-6 animate-in slide-in-from-right-4 duration-300">
                <div className="space-y-2">
                    <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">Email</label>
                    <div className="relative">
                        <Mail className="absolute left-4 top-4 w-5 h-5 text-gray-500" />
                        <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="Email" className="w-full bg-card border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                    </div>
                </div>
                <div className="space-y-2">
                    <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">Password</label>
                    <div className="relative">
                        <Lock className="absolute left-4 top-4 w-5 h-5 text-gray-500" />
                        <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="Password" className="w-full bg-card border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                    </div>
                </div>
                <button onClick={nextStep} className="w-full bg-secondary text-white h-14 rounded-2xl font-bold text-lg flex items-center justify-center gap-2 mt-8 shadow-lg shadow-secondary/20 active:scale-[0.98]">
                    Avanti <ArrowRight className="w-5 h-5" />
                </button>
            </div>
        )}

        {step === 'personal' && (
            <div className="space-y-6 animate-in slide-in-from-right-4 duration-300">
                <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                        <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">Nome</label>
                        <input type="text" value={firstName} onChange={e => setFirstName(e.target.value)} placeholder="Nome" className="w-full bg-card border border-white/5 rounded-2xl py-4 px-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                    </div>
                    <div className="space-y-2">
                        <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">Cognome</label>
                        <input type="text" value={lastName} onChange={e => setLastName(e.target.value)} placeholder="Cognome" className="w-full bg-card border border-white/5 rounded-2xl py-4 px-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                    </div>
                </div>
                <div className="space-y-2">
                    <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">Data di Nascita</label>
                    <div className="relative">
                        <Calendar className="absolute left-4 top-4 w-5 h-5 text-gray-500" />
                        <input type="date" value={dob} onChange={e => setDob(e.target.value)} className="w-full bg-card border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                    </div>
                </div>
                <button onClick={nextStep} className="w-full bg-secondary text-white h-14 rounded-2xl font-bold text-lg flex items-center justify-center gap-2 mt-8 shadow-lg shadow-secondary/20 active:scale-[0.98]">
                    Avanti <ArrowRight className="w-5 h-5" />
                </button>
            </div>
        )}

        {step === 'photo' && (
            <div className="flex flex-col items-center gap-10 animate-in slide-in-from-right-4 duration-300">
                <div className="text-center px-4">
                    <p className="text-gray-400 text-sm leading-relaxed">Mostra ai tuoi compagni chi sei. Carica una foto professionale o un avatar.</p>
                </div>
                
                <div 
                    onClick={handleProfileImageClick}
                    className="relative w-48 h-48 group cursor-pointer"
                >
                    <div className="w-full h-full rounded-[2.5rem] border-4 border-white/5 bg-card overflow-hidden flex items-center justify-center transition-all group-hover:border-secondary shadow-2xl group-hover:shadow-secondary/20">
                        {avatarUrl ? (
                            <img src={avatarUrl} alt="Avatar Preview" className="w-full h-full object-cover" />
                        ) : (
                            <Camera className="w-14 h-14 text-gray-700" />
                        )}
                        <div className="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                            <Camera className="w-10 h-10 text-white" />
                        </div>
                    </div>
                    <div className="absolute -bottom-2 -right-2 bg-secondary p-4 rounded-2xl border-4 border-background shadow-xl">
                        <PlusIcon className="w-6 h-6 text-white" />
                    </div>
                </div>

                <div className="w-full flex flex-col gap-4 mt-4">
                    <button 
                        onClick={nextStep}
                        className="w-full bg-secondary text-white h-16 rounded-2xl font-bold text-lg flex items-center justify-center gap-2 shadow-xl shadow-secondary/25 hover:brightness-110 active:scale-[0.98] transition-all"
                    >
                        {avatarUrl.includes('unsplash') ? 'Salta per ora' : 'Ottimo, Continua'} <ArrowRight className="w-5 h-5" />
                    </button>
                    <button 
                        onClick={handleProfileImageClick}
                        className="w-full bg-white/5 text-gray-500 h-14 rounded-2xl font-bold text-base hover:bg-white/10 transition-colors"
                    >
                        Scegli dalla galleria
                    </button>
                </div>
            </div>
        )}

        {step === 'physical' && (
            <div className="space-y-6 animate-in slide-in-from-right-4 duration-300">
                <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                        <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">Altezza (cm)</label>
                        <div className="relative">
                            <Ruler className="absolute left-4 top-4 w-5 h-5 text-gray-500" />
                            <input type="number" value={height} onChange={e => setHeight(e.target.value)} className="w-full bg-card border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                        </div>
                    </div>
                    <div className="space-y-2">
                        <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">Peso (kg)</label>
                        <div className="relative">
                            <Monitor className="absolute left-4 top-4 w-5 h-5 text-gray-500" />
                            <input type="number" value={weight} onChange={e => setWeight(e.target.value)} className="w-full bg-card border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                        </div>
                    </div>
                </div>
                <div className="space-y-2">
                    <label className="text-xs font-black text-gray-600 uppercase tracking-widest ml-1">FC Max (bpm)</label>
                    <div className="relative">
                        <Heart className="absolute left-4 top-4 w-5 h-5 text-gray-500" />
                        <input type="number" value={maxHr} onChange={e => setMaxHr(e.target.value)} className="w-full bg-card border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:ring-1 focus:ring-secondary outline-none" />
                    </div>
                </div>
                <button onClick={handleFinishRegistration} className="w-full bg-secondary text-white h-16 rounded-2xl font-bold text-lg flex items-center justify-center gap-2 mt-8 shadow-xl shadow-secondary/20 active:scale-[0.98] transition-all">
                    Completa Profilo <Check className="w-6 h-6" />
                </button>
            </div>
        )}
      </main>

      <footer className="mt-8 flex justify-center">
          <button onClick={() => setIsSignUp(false)} className="text-gray-500 text-sm font-bold hover:text-white transition">
              Hai già un account? <span className="text-secondary">Accedi</span>
          </button>
      </footer>
    </div>
  );
};

const PlusIcon = ({ className }: { className?: string }) => (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" className={className}><path d="M5 12h14"/><path d="M12 5v14"/></svg>
);

export default Auth;
