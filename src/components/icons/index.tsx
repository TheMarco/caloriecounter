import {
  CameraIcon,
  MicrophoneIcon,
  PencilIcon,
  HomeIcon,
  ChartBarIcon,
  Cog6ToothIcon,
  BeakerIcon,
  XMarkIcon,
  CheckIcon,
  ExclamationTriangleIcon,
  InformationCircleIcon,
  TrashIcon,
  PlusIcon,
  ArrowPathIcon,
  SignalIcon,
  WifiIcon,
} from '@heroicons/react/24/outline';

import {
  CameraIcon as CameraSolid,
  MicrophoneIcon as MicrophoneSolid,
  PencilIcon as PencilSolid,
  HomeIcon as HomeSolid,
  ChartBarIcon as ChartBarSolid,
  Cog6ToothIcon as Cog6ToothSolid,
} from '@heroicons/react/24/solid';

// Icon component props
interface IconProps {
  className?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  solid?: boolean;
}

// Size mappings
const sizeClasses = {
  sm: 'w-4 h-4',
  md: 'w-5 h-5',
  lg: 'w-6 h-6',
  xl: 'w-8 h-8',
};

// Icon wrapper component
function Icon({ 
  children, 
  className = '', 
  size = 'md' 
}: { 
  children: React.ReactNode; 
  className?: string; 
  size?: 'sm' | 'md' | 'lg' | 'xl';
}) {
  return (
    <span className={`inline-flex ${sizeClasses[size]} ${className}`}>
      {children}
    </span>
  );
}

// Specific icon components
export function CameraIconComponent({ className = '', size = 'md', solid = false }: IconProps) {
  const IconComponent = solid ? CameraSolid : CameraIcon;
  return (
    <Icon className={className} size={size}>
      <IconComponent />
    </Icon>
  );
}

export function MicrophoneIconComponent({ className = '', size = 'md', solid = false }: IconProps) {
  const IconComponent = solid ? MicrophoneSolid : MicrophoneIcon;
  return (
    <Icon className={className} size={size}>
      <IconComponent />
    </Icon>
  );
}

export function PencilIconComponent({ className = '', size = 'md', solid = false }: IconProps) {
  const IconComponent = solid ? PencilSolid : PencilIcon;
  return (
    <Icon className={className} size={size}>
      <IconComponent />
    </Icon>
  );
}

export function HomeIconComponent({ className = '', size = 'md', solid = false }: IconProps) {
  const IconComponent = solid ? HomeSolid : HomeIcon;
  return (
    <Icon className={className} size={size}>
      <IconComponent />
    </Icon>
  );
}

export function ChartIconComponent({ className = '', size = 'md', solid = false }: IconProps) {
  const IconComponent = solid ? ChartBarSolid : ChartBarIcon;
  return (
    <Icon className={className} size={size}>
      <IconComponent />
    </Icon>
  );
}

export function SettingsIconComponent({ className = '', size = 'md', solid = false }: IconProps) {
  const IconComponent = solid ? Cog6ToothSolid : Cog6ToothIcon;
  return (
    <Icon className={className} size={size}>
      <IconComponent />
    </Icon>
  );
}

export function TestIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <BeakerIcon />
    </Icon>
  );
}

export function CloseIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <XMarkIcon />
    </Icon>
  );
}

export function CheckIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <CheckIcon />
    </Icon>
  );
}

export function WarningIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <ExclamationTriangleIcon />
    </Icon>
  );
}

export function InfoIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <InformationCircleIcon />
    </Icon>
  );
}

export function DeleteIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <TrashIcon />
    </Icon>
  );
}

export function PlusIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <PlusIcon />
    </Icon>
  );
}

export function RefreshIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <ArrowPathIcon />
    </Icon>
  );
}

export function OfflineIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <SignalIcon />
    </Icon>
  );
}

export function OnlineIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <WifiIcon />
    </Icon>
  );
}

export function BarcodeIconComponent({ className = '', size = 'md' }: IconProps) {
  return (
    <Icon className={className} size={size}>
      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 7v2a3 3 0 003 3h2m0-8V4a1 1 0 011-1h2a1 1 0 011 1v1m0 0V4a1 1 0 011-1h2a1 1 0 011 1v1m0 0V4a1 1 0 011-1h2a1 1 0 011 1v1m-8 8v6m2-6v6m2-6v6m2-6v6m2-6v6m-8-6h8" />
        <rect x="2" y="6" width="20" height="12" rx="2" stroke="currentColor" strokeWidth="2" fill="none"/>
        <line x1="4" y1="8" x2="4" y2="16" stroke="currentColor" strokeWidth="1"/>
        <line x1="6" y1="8" x2="6" y2="16" stroke="currentColor" strokeWidth="2"/>
        <line x1="8" y1="8" x2="8" y2="16" stroke="currentColor" strokeWidth="1"/>
        <line x1="10" y1="8" x2="10" y2="16" stroke="currentColor" strokeWidth="1"/>
        <line x1="12" y1="8" x2="12" y2="16" stroke="currentColor" strokeWidth="2"/>
        <line x1="14" y1="8" x2="14" y2="16" stroke="currentColor" strokeWidth="1"/>
        <line x1="16" y1="8" x2="16" y2="16" stroke="currentColor" strokeWidth="2"/>
        <line x1="18" y1="8" x2="18" y2="16" stroke="currentColor" strokeWidth="1"/>
        <line x1="20" y1="8" x2="20" y2="16" stroke="currentColor" strokeWidth="1"/>
      </svg>
    </Icon>
  );
}
