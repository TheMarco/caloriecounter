import { render, screen } from '@testing-library/react';
import { TotalCard } from '@/components/TotalCard';

describe.skip('TotalCard', () => {
  const defaultProps = {
    total: 1500,
    target: 2000,
    date: '2025-01-06',
  };

  it('should render total calories', () => {
    render(<TotalCard {...defaultProps} />);
    
    expect(screen.getByText('1,500')).toBeInTheDocument();
    expect(screen.getByText('calories consumed')).toBeInTheDocument();
  });

  it('should render formatted date', () => {
    render(<TotalCard {...defaultProps} />);
    
    expect(screen.getByText('Monday, January 6')).toBeInTheDocument();
  });

  it('should show remaining calories when under target', () => {
    render(<TotalCard {...defaultProps} />);
    
    expect(screen.getByText('500 calories remaining')).toBeInTheDocument();
    expect(screen.getByText('75% of daily target')).toBeInTheDocument();
  });

  it('should show over target message when calories exceed target', () => {
    render(<TotalCard {...defaultProps} total={2500} />);
    
    expect(screen.getByText('Over target by 500 calories')).toBeInTheDocument();
    expect(screen.getByText('Consider lighter meals or more activity')).toBeInTheDocument();
  });

  it('should display progress bar with correct percentage', () => {
    render(<TotalCard {...defaultProps} />);
    
    const progressBar = document.querySelector('.h-3.rounded-full.transition-all');
    expect(progressBar).toHaveStyle('width: 75%');
  });

  it('should handle zero calories', () => {
    render(<TotalCard {...defaultProps} total={0} />);
    
    expect(screen.getByText('0')).toBeInTheDocument();
    expect(screen.getByText('2,000 calories remaining')).toBeInTheDocument();
    expect(screen.getByText('0% of daily target')).toBeInTheDocument();
  });

  it('should display quick stats correctly', () => {
    render(<TotalCard {...defaultProps} />);
    
    // Percentage of target
    expect(screen.getByText('75%')).toBeInTheDocument();
    expect(screen.getByText('of target')).toBeInTheDocument();
    
    // Daily goal
    expect(screen.getByText('2,000')).toBeInTheDocument();
    expect(screen.getByText('daily goal')).toBeInTheDocument();
    
    // Difference vs target
    expect(screen.getByText('-500')).toBeInTheDocument();
    expect(screen.getByText('vs target')).toBeInTheDocument();
  });

  it('should show positive difference when over target', () => {
    render(<TotalCard {...defaultProps} total={2200} />);
    
    expect(screen.getByText('+200')).toBeInTheDocument();
  });

  it('should use different colors based on progress', () => {
    const { rerender } = render(<TotalCard {...defaultProps} total={1200} />);
    
    // Under 60% should be green
    let totalElement = screen.getByText('1,200');
    expect(totalElement).toHaveClass('text-green-600');
    
    // 60-80% should be yellow
    rerender(<TotalCard {...defaultProps} total={1400} />);
    totalElement = screen.getByText('1,400');
    expect(totalElement).toHaveClass('text-yellow-600');
    
    // 80-100% should be orange
    rerender(<TotalCard {...defaultProps} total={1800} />);
    totalElement = screen.getByText('1,800');
    expect(totalElement).toHaveClass('text-orange-600');
    
    // Over 100% should be red
    rerender(<TotalCard {...defaultProps} total={2200} />);
    totalElement = screen.getByText('2,200');
    expect(totalElement).toHaveClass('text-red-600');
  });
});
