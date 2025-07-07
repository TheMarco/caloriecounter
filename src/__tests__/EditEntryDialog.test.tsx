import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { EditEntryDialog } from '@/components/EditEntryDialog';
import type { Entry } from '@/types';

const mockEntry: Entry = {
  id: 'test-id',
  dt: '2024-01-01',
  ts: Date.now(),
  food: 'Apple',
  qty: 1,
  unit: 'piece',
  kcal: 95,
  method: 'text',
};

describe('EditEntryDialog', () => {
  const mockOnSave = jest.fn();
  const mockOnCancel = jest.fn();

  beforeEach(() => {
    mockOnSave.mockClear();
    mockOnCancel.mockClear();
  });

  it('should not render when isOpen is false', () => {
    render(
      <EditEntryDialog
        isOpen={false}
        entry={mockEntry}
        isLoading={false}
        onSave={mockOnSave}
        onCancel={mockOnCancel}
      />
    );

    expect(screen.queryByText('Edit Entry')).not.toBeInTheDocument();
  });

  it('should render edit form when isOpen is true', () => {
    render(
      <EditEntryDialog
        isOpen={true}
        entry={mockEntry}
        isLoading={false}
        onSave={mockOnSave}
        onCancel={mockOnCancel}
      />
    );

    expect(screen.getByText('Edit Entry')).toBeInTheDocument();
    expect(screen.getByDisplayValue('Apple')).toBeInTheDocument();
    expect(screen.getByDisplayValue('1')).toBeInTheDocument();
    expect(screen.getByDisplayValue('95')).toBeInTheDocument();
  });

  it('should call onSave with updated entry when save button is clicked', async () => {
    render(
      <EditEntryDialog
        isOpen={true}
        entry={mockEntry}
        isLoading={false}
        onSave={mockOnSave}
        onCancel={mockOnCancel}
      />
    );

    // Change the food name
    const foodInput = screen.getByDisplayValue('Apple');
    fireEvent.change(foodInput, { target: { value: 'Large Apple' } });

    // Change the quantity
    const qtyInput = screen.getByDisplayValue('1');
    fireEvent.change(qtyInput, { target: { value: '2' } });

    // Click save
    const saveButton = screen.getByText('Save Changes');
    fireEvent.click(saveButton);

    await waitFor(() => {
      expect(mockOnSave).toHaveBeenCalledWith({
        ...mockEntry,
        food: 'Large Apple',
        qty: 2,
        kcal: 190, // Should auto-calculate: 95 * 2
      });
    });
  });

  it('should call onCancel when cancel button is clicked', () => {
    render(
      <EditEntryDialog
        isOpen={true}
        entry={mockEntry}
        isLoading={false}
        onSave={mockOnSave}
        onCancel={mockOnCancel}
      />
    );

    const cancelButton = screen.getByText('Cancel');
    fireEvent.click(cancelButton);

    expect(mockOnCancel).toHaveBeenCalled();
  });

  it('should show loading state when isLoading is true', () => {
    render(
      <EditEntryDialog
        isOpen={true}
        entry={mockEntry}
        isLoading={true}
        onSave={mockOnSave}
        onCancel={mockOnCancel}
      />
    );

    expect(screen.getByText('Saving changes...')).toBeInTheDocument();
    expect(screen.queryByText('Save Changes')).not.toBeInTheDocument();
  });

  it('should disable save button when food is empty', () => {
    render(
      <EditEntryDialog
        isOpen={true}
        entry={mockEntry}
        isLoading={false}
        onSave={mockOnSave}
        onCancel={mockOnCancel}
      />
    );

    // Clear the food name
    const foodInput = screen.getByDisplayValue('Apple');
    fireEvent.change(foodInput, { target: { value: '' } });

    const saveButton = screen.getByText('Save Changes');
    expect(saveButton).toBeDisabled();
  });
});
