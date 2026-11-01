package concurrent_reservation_service.audit;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
@Service
public class AsyncAuditService {
    @Async
    public void logEvent(String action, String details) {
        System.out.println(
                "[ASYNC AUDIT] Thread: "
                        + Thread.currentThread().getName()
                        + " | Action: " + action
                        + " | Details: " + details
        );
    }
}