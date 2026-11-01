package concurrent_reservation_service;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
@SpringBootApplication
@EnableAsync
public class ConcurrentReservationServiceApplication {
	public static void main(String[] args) {
		SpringApplication.run(
				ConcurrentReservationServiceApplication.class,
				args
		);
	}
}
