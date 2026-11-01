package concurrent_reservation_service.persistence;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import concurrent_reservation_service.model.Reservation;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

@Repository
@ConditionalOnProperty(
        name = "reservation.storage",
        havingValue = "json",
        matchIfMissing = true
)

public class JsonReservationStore implements ReservationStore {
    private final Path file = Path.of("data", "reservations.json");
    private final ObjectMapper mapper = new ObjectMapper()
            .registerModule(new JavaTimeModule());
    @Override
    public List<Reservation> load() {
        if (Files.notExists(file)) {
            return new ArrayList<>();
        }
        try {
            return mapper.readValue(
                    file.toFile(),
                    new TypeReference<List<Reservation>>() {}
            );
        } catch (IOException e) {
            throw new IllegalStateException(
                    "Unable to load reservation data", e);
        }
    }

    @Override
    public void save(List<Reservation> reservations) {
        try {
            Files.createDirectories(file.getParent());
            mapper.writerWithDefaultPrettyPrinter()
                    .writeValue(file.toFile(), reservations);
        } catch (IOException e) {
            throw new IllegalStateException(
                    "Unable to save reservation data", e);

        }
    }
}
