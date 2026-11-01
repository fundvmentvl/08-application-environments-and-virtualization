package concurrent_reservation_service.persistence;
import concurrent_reservation_service.model.Reservation;
import java.util.List;
public interface ReservationStore {
    List<Reservation> load();
    void save(List<Reservation> reservations);
}