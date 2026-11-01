package concurrent_reservation_service.model;
import java.time.LocalDateTime;

public record Reservation(
        String id,
        String appointmentSlotId,
        String customerName,
        LocalDateTime createdAt
) {
}