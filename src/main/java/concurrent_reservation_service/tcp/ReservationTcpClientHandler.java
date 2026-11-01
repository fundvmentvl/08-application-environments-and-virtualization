package concurrent_reservation_service.tcp;
import concurrent_reservation_service.service.ReservationService;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

public class ReservationTcpClientHandler implements Runnable {
    private final Socket socket;
    private final ReservationService reservationService;
    public ReservationTcpClientHandler(
            Socket socket,
            ReservationService reservationService) {
        this.socket = socket;
        this.reservationService = reservationService;
    }

    @Override
    public void run() {
        try (
                BufferedReader input = new BufferedReader(
                        new InputStreamReader(
                                socket.getInputStream(),
                                StandardCharsets.UTF_8));
                PrintWriter output = new PrintWriter(
                        socket.getOutputStream(), true,
                        StandardCharsets.UTF_8)
        ) {
            output.println("Connected to Appointment Reservation TCP Server");
            output.println("Commands: LIST, BOOK, GET, CANCEL, ALL, HELP, QUIT");
            String request;

            while ((request = input.readLine()) != null) {
                if (request.length() > 2048) {
                    output.println("ERROR: Request too long");
                    break;
                }
                String response = processCommand(request);
                output.println(response);
                if ("QUIT".equalsIgnoreCase(request.trim())) {
                    break;
                }
            }

        } catch (IOException e) {
            System.err.println("TCP connection error: " + e.getMessage());
        }
    }

    private String processCommand(String request) {
        if (request == null || request.isBlank()) {
            return "ERROR: Command is required";
        }

        String[] parts = request.trim().split("\\s+", 3);
        String command = parts[0].toUpperCase(Locale.ROOT);

        try {
            return switch (command) {
                case "LIST" -> {
                    if (parts.length != 1) {
                        yield "ERROR: Usage LIST";
                    }
                    yield "AVAILABLE: " + reservationService.getAvailableSlots();
                }

                case "BOOK" -> {
                    if (parts.length < 3) {
                        yield "ERROR: Usage BOOK <slotId> <customerName>";
                    }
                    var reservation = reservationService.bookAppointment(
                            parts[1], parts[2]);
                    yield "BOOKED: " + reservation;
                }

                case "GET" -> {
                    if (parts.length != 2) {
                        yield "ERROR: Usage GET <reservationId>";
                    }
                    yield "RESERVATION: " +
                            reservationService.getReservation(parts[1]);
                }

                case "CANCEL" -> {
                    if (parts.length != 2) {
                        yield "ERROR: Usage CANCEL <reservationId>";
                    }
                    reservationService.cancelReservation(parts[1]);
                    yield "CANCELED: " + parts[1];
                }

                case "ALL" -> {
                    if (parts.length != 1) {
                        yield "ERROR: Usage ALL";
                    }
                    yield "RESERVATIONS: " +
                            reservationService.getAllReservations();
                }

                case "HELP" ->
                        "Commands: LIST | BOOK <slotId> <customerName> | " +
                                "GET <reservationId> | CANCEL <reservationId> | " +
                                "ALL | HELP | QUIT";
                case "QUIT" -> "Goodbye";
                default -> "ERROR: Unknown command. Type HELP.";
            };

        } catch (IllegalArgumentException |
                 IllegalStateException e) {
            return "ERROR: " + e.getMessage();
        } catch (RuntimeException e) {
            System.err.println("Unexpected TCP request failure: " +
                    e.getClass().getSimpleName());
            return "ERROR: Unable to process request";
        }
    }
}
