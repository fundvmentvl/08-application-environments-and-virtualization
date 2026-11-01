package concurrent_reservation_service.tcp;
import concurrent_reservation_service.service.ReservationService;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
@Component
public class ReservationTcpServer implements CommandLineRunner {
    private final ReservationService reservationService;
    private final ExecutorService clientPool =
            Executors.newFixedThreadPool(10);
    public ReservationTcpServer(ReservationService reservationService) {
        this.reservationService = reservationService;
    }
    @Override
    public void run(String... args) {
        Thread serverThread = new Thread(this::startServer);
        serverThread.setName("reservation-tcp-server");
        serverThread.setDaemon(true);
        serverThread.start();
    }
    private void startServer() {
        try (ServerSocket serverSocket = new ServerSocket(9090)) {
            System.out.println("TCP Reservation Server running on port 9090");
            while (!Thread.currentThread().isInterrupted()) {
                Socket clientSocket = serverSocket.accept();
                clientPool.execute(() -> {
                    try (Socket socket = clientSocket) {
                        new ReservationTcpClientHandler(
                                socket, reservationService
                        ).run();
                    } catch (IOException e) {
                        System.err.println("TCP client error: " + e.getMessage());
                    }
                });
            }
        } catch (IOException e) {
            System.err.println("TCP server error: " + e.getMessage());
        }
    }
}
