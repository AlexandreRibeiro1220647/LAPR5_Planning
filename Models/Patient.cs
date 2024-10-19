namespace TodoApi.Models;

public class Patient : User
{
    public DateTime Birthday { get; set; }
    public string? Gender { get; set; }
    public List<string> MedicalConditions { get; set; } = new List<string>();
    public string? EmergencyContact { get; set; }

        // Navigation property for appointments
    public virtual ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

}