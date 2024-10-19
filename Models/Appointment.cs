namespace TodoApi.Models
{
    public class Appointment
    {
        public long Id { get; set; } // Unique identifier for the appointment
        public long RequestId { get; set; } // Foreign key for the request associated with the appointment
        public long RoomId { get; set; } // Foreign key for the room where the appointment takes place
        public DateTime Date { get; set; } // Date of the appointment
        public AppointmentStatus Status { get; set; } // Status of the appointment (e.g., Scheduled, Completed, Canceled)
    }
}
