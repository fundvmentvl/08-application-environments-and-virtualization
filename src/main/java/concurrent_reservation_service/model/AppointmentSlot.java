package concurrent_reservation_service.model;
import java.time.LocalDate;
import java.time.LocalTime;

public record AppointmentSlot(
        String id,
        LocalDate date,
        LocalTime startTime,
        LocalTime endTime
) {
}
