
// Add React import to fix "Cannot find namespace 'React'" error when using React.ElementType
import React from 'react';
import { 
  Snowflake, Mountain, Wind, Trophy, Activity, CircleDot, Target, Box, 
  Goal, Disc, Footprints, Timer, Bike, Waves, Navigation, Map, 
  Dumbbell, Flame, Zap, Swords, Sailboat, Anchor, Flag, Music, Car, Fish, Cloud,
  Move, Footprints as FootprintsIcon
} from 'lucide-react';

export interface SportDef {
  id: string;
  name: string;
  icon: React.ElementType;
  category: string;
}

export const sportsData: SportDef[] = [
    // WINTER
    { id: 'alpine_skiing', name: 'Alpine Skiing', icon: Snowflake, category: 'Winter' },
    { id: 'snowboarding', name: 'Snowboarding', icon: Mountain, category: 'Winter' },
    { id: 'xc_skiing', name: 'XC Skiing', icon: Wind, category: 'Winter' },
    { id: 'ice_hockey', name: 'Ice Hockey', icon: Trophy, category: 'Winter' },
    { id: 'ice_skating', name: 'Ice Skating', icon: Wind, category: 'Winter' },
    { id: 'figure_skating', name: 'Figure Skating', icon: Activity, category: 'Winter' },
    { id: 'curling', name: 'Curling', icon: CircleDot, category: 'Winter' },
    { id: 'biathlon', name: 'Biathlon', icon: Target, category: 'Winter' },
    { id: 'ski_touring', name: 'Ski Touring', icon: Mountain, category: 'Winter' },
    { id: 'bobsleigh', name: 'Bobsleigh', icon: Box, category: 'Winter' },

    // TEAM
    { id: 'soccer', name: 'Soccer', icon: Goal, category: 'Team' },
    { id: 'basketball', name: 'Basketball', icon: Trophy, category: 'Team' },
    { id: 'am_football', name: 'American Football', icon: Trophy, category: 'Team' },
    { id: 'rugby', name: 'Rugby', icon: Trophy, category: 'Team' },
    { id: 'volleyball', name: 'Volleyball', icon: Activity, category: 'Team' },
    { id: 'beach_volley', name: 'Beach Volley', icon: Activity, category: 'Team' },
    { id: 'baseball', name: 'Baseball', icon: Trophy, category: 'Team' },
    { id: 'softball', name: 'Softball', icon: Trophy, category: 'Team' },
    { id: 'cricket', name: 'Cricket', icon: Activity, category: 'Team' },
    { id: 'handball', name: 'Handball', icon: Trophy, category: 'Team' },
    { id: 'lacrosse', name: 'Lacrosse', icon: Trophy, category: 'Team' },
    { id: 'field_hockey', name: 'Field Hockey', icon: Trophy, category: 'Team' },
    { id: 'water_polo', name: 'Water Polo', icon: Waves, category: 'Team' },
    { id: 'ultimate', name: 'Ultimate Frisbee', icon: Disc, category: 'Team' },

    // ENDURANCE / CARDIO
    { id: 'running_road', name: 'Running', icon: Footprints, category: 'Endurance' },
    { id: 'running_trail', name: 'Trail Running', icon: Mountain, category: 'Endurance' },
    { id: 'track_field', name: 'Track & Field', icon: Timer, category: 'Endurance' },
    { id: 'cycling_road', name: 'Cycling', icon: Bike, category: 'Endurance' },
    { id: 'cycling_mtb', name: 'Mountain Biking', icon: Mountain, category: 'Endurance' },
    { id: 'cycling_gravel', name: 'Gravel Cycling', icon: Bike, category: 'Endurance' },
    { id: 'swimming', name: 'Swimming', icon: Waves, category: 'Endurance' },
    { id: 'triathlon', name: 'Triathlon', icon: Timer, category: 'Endurance' },
    { id: 'rowing', name: 'Rowing', icon: Waves, category: 'Endurance' },
    { id: 'hiking', name: 'Hiking', icon: Navigation, category: 'Endurance' },
    { id: 'walking', name: 'Walking', icon: Footprints, category: 'Endurance' },
    { id: 'orienteering', name: 'Orienteering', icon: Map, category: 'Endurance' },

    // FITNESS & STRENGTH
    { id: 'athletic_prep', name: 'Athletic Prep / Other', icon: Zap, category: 'Fitness' },
    { id: 'stretching', name: 'Allungamento (Stretching)', icon: Move, category: 'Fitness' },
    { id: 'weightlifting', name: 'Weightlifting', icon: Dumbbell, category: 'Fitness' },
    { id: 'powerlifting', name: 'Powerlifting', icon: Dumbbell, category: 'Fitness' },
    { id: 'crossfit', name: 'CrossFit', icon: Flame, category: 'Fitness' },
    { id: 'bodybuilding', name: 'Bodybuilding', icon: Dumbbell, category: 'Fitness' },
    { id: 'calisthenics', name: 'Calisthenics', icon: Activity, category: 'Fitness' },
    { id: 'hiit', name: 'HIIT', icon: Zap, category: 'Fitness' },
    { id: 'circuit', name: 'Circuit Training', icon: Timer, category: 'Fitness' },
    { id: 'yoga', name: 'Yoga', icon: Activity, category: 'Fitness' },
    { id: 'pilates', name: 'Pilates', icon: Activity, category: 'Fitness' },
    { id: 'spinning', name: 'Spinning', icon: Bike, category: 'Fitness' },
    { id: 'stair_climber', name: 'Stair Climber', icon: Mountain, category: 'Fitness' },

    // COMBAT
    { id: 'boxing', name: 'Boxing', icon: Swords, category: 'Combat' },
    { id: 'mma', name: 'MMA', icon: Swords, category: 'Combat' },
    { id: 'bjj', name: 'BJJ / Grappling', icon: Swords, category: 'Combat' },
    { id: 'wrestling', name: 'Wrestling', icon: Swords, category: 'Combat' },
    { id: 'muay_thai', name: 'Muay Thai', icon: Swords, category: 'Combat' },
    { id: 'judo', name: 'Judo', icon: Swords, category: 'Combat' },
    { id: 'karate', name: 'Karate', icon: Swords, category: 'Combat' },
    { id: 'taekwondo', name: 'Taekwondo', icon: Swords, category: 'Combat' },
    { id: 'kickboxing', name: 'Kickboxing', icon: Swords, category: 'Combat' },
    { id: 'fencing', name: 'Fencing', icon: Swords, category: 'Combat' },

    // RACQUET
    { id: 'tennis', name: 'Tennis', icon: Activity, category: 'Racquet' },
    { id: 'padel', name: 'Padel', icon: Activity, category: 'Racquet' },
    { id: 'squash', name: 'Squash', icon: Activity, category: 'Racquet' },
    { id: 'badminton', name: 'Badminton', icon: Wind, category: 'Racquet' },
    { id: 'table_tennis', name: 'Table Tennis', icon: CircleDot, category: 'Racquet' },
    { id: 'pickleball', name: 'Pickleball', icon: Activity, category: 'Racquet' },

    // WATER
    { id: 'surfing', name: 'Surfing', icon: Waves, category: 'Water' },
    { id: 'sailing', name: 'Sailing', icon: Sailboat, category: 'Water' },
    { id: 'kayaking', name: 'Kayaking', icon: Waves, category: 'Water' },
    { id: 'sup', name: 'Stand Up Paddle', icon: Waves, category: 'Water' },
    { id: 'diving', name: 'Diving', icon: Anchor, category: 'Water' },
    { id: 'kitesurfing', name: 'Kitesurfing', icon: Wind, category: 'Water' },
    { id: 'wakeboarding', name: 'Wakeboarding', icon: Waves, category: 'Water' },

    // SKILL / OTHER
    { id: 'golf', name: 'Golf', icon: Flag, category: 'Skill' },
    { id: 'archery', name: 'Archery', icon: Target, category: 'Skill' },
    { id: 'climbing', name: 'Rock Climbing', icon: Mountain, category: 'Skill' },
    { id: 'bouldering', name: 'Bouldering', icon: Mountain, category: 'Skill' },
    { id: 'skateboarding', name: 'Skateboarding', icon: Box, category: 'Skill' },
    { id: 'gymnastics', name: 'Gymnastics', icon: Activity, category: 'Skill' },
    { id: 'dance', name: 'Dance', icon: Music, category: 'Skill' },
    { id: 'equestrian', name: 'Horse Riding', icon: Trophy, category: 'Skill' },
    { id: 'motorsport', name: 'Motorsport', icon: Car, category: 'Skill' },
    { id: 'motocross', name: 'Motocross', icon: Bike, category: 'Skill' },
    { id: 'bowling', name: 'Bowling', icon: CircleDot, category: 'Skill' },
    { id: 'fishing', name: 'Fishing', icon: Fish, category: 'Skill' },
    { id: 'billiards', name: 'Billiards', icon: CircleDot, category: 'Skill' },
    { id: 'darts', name: 'Darts', icon: Target, category: 'Skill' },
    { id: 'paragliding', name: 'Paragliding', icon: Cloud, category: 'Skill' },
];
