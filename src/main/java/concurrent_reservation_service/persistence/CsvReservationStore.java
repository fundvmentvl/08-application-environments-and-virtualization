package concurrent_reservation_service.persistence;
import concurrent_reservation_service.model.Reservation;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
@Repository
@ConditionalOnProperty(
        name = "reservation.storage",
        havingValue = "csv"
)
public class CsvReservationStore implements ReservationStore {
    private final Path file = Path.of("data", "reservations.csv");
    @Override
    public List<Reservation> load() {
        if (Files.notExists(file)) {
            return new ArrayList<>();
        }
        try {
            List<Reservation> reservations = new ArrayList<>();
            List<String> lines = Files.readAllLines(
                    file, StandardCharsets.UTF_8);
            for (int i = 1; i < lines.size(); i++) {
                if (lines.get(i).isBlank()) {
                    continue;
                }
                List<String> values = parseCsvLine(lines.get(i));
                if (values.size() != 4) {
                    throw new IllegalStateException(
                            "Invalid reservation CSV record");
                }
                reservations.add(new Reservation(
                        values.get(0),
                        values.get(1),
                        values.get(2),
                        LocalDateTime.parse(values.get(3))
                ));
            }
            return reservations;
        } catch (IOException | RuntimeException e) {
            throw new IllegalStateException(
                    "Unable to load reservation data", e);
        }
    }
    @Override
    public void save(List<Reservation> reservations) {
        try {
            Files.createDirectories(file.getParent());
            List<String> lines = new ArrayList<>();
            lines.add("id,appointmentSlotId,customerName,createdAt");
            for (Reservation reservation : reservations) {
                lines.add(
                        escape(reservation.id()) + "," +
                                escape(reservation.appointmentSlotId()) + "," +
                                escape(reservation.customerName()) + "," +
                                escape(reservation.createdAt().toString())
                );
            }
            Files.write(file, lines, StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException(
                    "Unable to save reservation data", e);
        }
    }
    private String escape(String value) {
        return "\"" + value.replace("\"", "\"\"") + "\"";
    }
    private List<String> parseCsvLine(String line) {
        List<String> values = new ArrayList<>();
        StringBuilder field = new StringBuilder();
        boolean quoted = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (c == '"') {
                if (quoted && i + 1 < line.length()
                        && line.charAt(i + 1) == '"') {
                    field.append('"');
                    i++;
                } else {
                    quoted = !quoted;
                }
            } else if (c == ',' && !quoted) {
                values.add(field.toString());
                field.setLength(0);
            } else {
                field.append(c);
            }
        }
        if (quoted) {
            throw new IllegalArgumentException(
                    "Unclosed CSV quotation");
        }
        values.add(field.toString());
        return values;
    }
}