
import React from 'react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, AreaChart, Area, ComposedChart, CartesianGrid } from 'recharts';

interface WeightData {
  date: string;
  weight: number;
  bodyFat?: number;
}

interface HeightData {
  date: string;
  height: number;
}

interface PRData {
  date: string;
  weight: number;
}

interface JumpData {
  date: string;
  value: number;
}

interface WeightChartProps {
  data?: WeightData[];
}

interface HeightChartProps {
  data?: HeightData[];
}

interface PRChartProps {
  data?: PRData[];
}

interface JumpChartProps {
  data?: JumpData[];
}

export const WeightChart: React.FC<WeightChartProps> = ({ data }) => {
  // Default fallback data if none provided
  const chartData = data || [
    { date: 'Oct 1', weight: 178, bodyFat: 15 },
    { date: 'Oct 5', weight: 177.5, bodyFat: 14.8 },
    { date: 'Oct 10', weight: 176.8, bodyFat: 14.7 },
    { date: 'Oct 15', weight: 177.2, bodyFat: 14.5 },
    { date: 'Oct 20', weight: 176.0, bodyFat: 14.2 },
    { date: 'Oct 25', weight: 175.4, bodyFat: 14.0 },
  ];

  return (
    <ResponsiveContainer width="100%" height="100%">
      <ComposedChart data={chartData}>
        <defs>
          <linearGradient id="colorWeight" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#13A4EC" stopOpacity={0.3}/>
            <stop offset="95%" stopColor="#13A4EC" stopOpacity={0}/>
          </linearGradient>
        </defs>
        
        <CartesianGrid vertical={false} stroke="rgba(255,255,255,0.05)" />
        
        {/* Weight Axis (Left) */}
        <YAxis 
          yAxisId="left" 
          domain={['dataMin - 1', 'dataMax + 1']} 
          orientation="left" 
          tick={{fill: '#6B7280', fontSize: 10}} 
          axisLine={false}
          tickLine={false}
          width={30}
        />
        
        {/* Body Fat Axis (Right) */}
        <YAxis 
          yAxisId="right" 
          domain={['dataMin - 1', 'dataMax + 1']} 
          orientation="right" 
          tick={{fill: '#00E091', fontSize: 10}} 
          axisLine={false}
          tickLine={false}
          width={30}
        />

        <XAxis 
          dataKey="date" 
          axisLine={false} 
          tickLine={false} 
          tick={{fill: '#9CA3AF', fontSize: 10}} 
          dy={10}
          minTickGap={20} // Prevents labels from overlapping in 1M view
        />

        <Tooltip 
          contentStyle={{ backgroundColor: '#23262D', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px' }}
          itemStyle={{ fontSize: '12px' }}
          labelStyle={{ color: '#9CA3AF', marginBottom: '5px', fontSize: '12px' }}
        />

        {/* Weight Area */}
        <Area 
          yAxisId="left"
          type="monotone" 
          dataKey="weight" 
          name="Weight"
          stroke="#13A4EC" 
          strokeWidth={3} 
          fillOpacity={1} 
          fill="url(#colorWeight)" 
          animationDuration={1000}
        />

        {/* Body Fat Line */}
        <Line 
          yAxisId="right"
          type="monotone" 
          dataKey="bodyFat" 
          name="Body Fat %"
          stroke="#00E091" 
          strokeWidth={2} 
          dot={false}
          strokeDasharray="4 4"
          animationDuration={1000}
        />
      </ComposedChart>
    </ResponsiveContainer>
  );
};

export const HeightChart: React.FC<HeightChartProps> = ({ data }) => {
  return (
    <ResponsiveContainer width="100%" height="100%">
      <AreaChart data={data}>
        <defs>
          <linearGradient id="colorHeight" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#8B5CF6" stopOpacity={0.3}/>
            <stop offset="95%" stopColor="#8B5CF6" stopOpacity={0}/>
          </linearGradient>
        </defs>
        
        <CartesianGrid vertical={false} stroke="rgba(255,255,255,0.05)" />
        
        <YAxis 
          domain={['dataMin - 2', 'dataMax + 2']} 
          orientation="left" 
          tick={{fill: '#6B7280', fontSize: 10}} 
          axisLine={false}
          tickLine={false}
          width={30}
        />

        <XAxis 
          dataKey="date" 
          axisLine={false} 
          tickLine={false} 
          tick={{fill: '#9CA3AF', fontSize: 10}} 
          dy={10}
          minTickGap={20}
        />

        <Tooltip 
          contentStyle={{ backgroundColor: '#23262D', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px' }}
          itemStyle={{ fontSize: '12px', color: '#8B5CF6' }}
          labelStyle={{ color: '#9CA3AF', marginBottom: '5px', fontSize: '12px' }}
        />

        <Area 
          type="monotone" 
          dataKey="height" 
          name="Height"
          stroke="#8B5CF6" 
          strokeWidth={3} 
          fillOpacity={1} 
          fill="url(#colorHeight)" 
          animationDuration={1000}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
};

export const PRChart: React.FC<PRChartProps> = ({ data }) => {
  if (!data || data.length === 0) return null;

  return (
    <ResponsiveContainer width="100%" height="100%">
      <AreaChart data={data}>
         <defs>
          <linearGradient id="colorPR" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#00E091" stopOpacity={0.3}/>
            <stop offset="95%" stopColor="#00E091" stopOpacity={0}/>
          </linearGradient>
        </defs>
        <XAxis 
            dataKey="date" 
            axisLine={false} 
            tickLine={false} 
            tick={{fill: '#9CA3AF', fontSize: 10}} 
            minTickGap={20}
        />
        <YAxis 
          domain={['dataMin - 5', 'dataMax + 5']} 
          orientation="left" 
          tick={{fill: '#6B7280', fontSize: 10}} 
          axisLine={false}
          tickLine={false}
          width={30}
        />
        <Tooltip 
           cursor={{stroke: 'rgba(255,255,255,0.1)'}}
           contentStyle={{ backgroundColor: '#23262D', border: 'none', borderRadius: '8px' }}
        />
        <Area type="stepAfter" dataKey="weight" stroke="#00E091" strokeWidth={3} fill="url(#colorPR)" />
      </AreaChart>
    </ResponsiveContainer>
  );
};

export const JumpChart: React.FC<JumpChartProps> = ({ data }) => {
  if (!data || data.length === 0) return null;

  return (
    <ResponsiveContainer width="100%" height="100%">
      <AreaChart data={data}>
         <defs>
          <linearGradient id="colorJump" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#F97316" stopOpacity={0.3}/>
            <stop offset="95%" stopColor="#F97316" stopOpacity={0}/>
          </linearGradient>
        </defs>
        <XAxis 
            dataKey="date" 
            axisLine={false} 
            tickLine={false} 
            tick={{fill: '#9CA3AF', fontSize: 10}} 
            minTickGap={20}
        />
        <YAxis 
          domain={['dataMin - 2', 'dataMax + 2']} 
          orientation="left" 
          tick={{fill: '#6B7280', fontSize: 10}} 
          axisLine={false}
          tickLine={false}
          width={30}
        />
        <Tooltip 
           cursor={{stroke: 'rgba(255,255,255,0.1)'}}
           contentStyle={{ backgroundColor: '#23262D', border: 'none', borderRadius: '8px' }}
        />
        <Area type="monotone" dataKey="value" stroke="#F97316" strokeWidth={3} fill="url(#colorJump)" />
      </AreaChart>
    </ResponsiveContainer>
  );
};
