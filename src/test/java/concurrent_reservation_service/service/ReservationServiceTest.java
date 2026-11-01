package concurrent_reservation_service.service;
import concurrent_reservation_service.audit.AsyncAuditService;
import concurrent_reservation_service.model.Reservation;
import concurrent_reservation_service.persistence.ReservationStore;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class ReservationServiceTest {
    private ReservationService service;
    private AsyncAuditService auditService;
    private ReservationStore reservationStore;
    @BeforeEach
    void setUp() {
        auditService = mock(AsyncAuditService.class);
        reservationStore = mock(ReservationStore.class);
        when(reservationStore.load()).thenReturn(List.of());
        service = new ReservationService(auditService, reservationStore);
    }
    @Test
    void shouldReturnFourAvailableSlots() {
        assertEquals(4, service.getAvailableSlots().size());
    }
    @Test
    void shouldBookAvailableAppointment() {
        Reservation reservation =
                service.bookAppointment("SLOT-001", "Customer A");
        assertNotNull(reservation.id());
        assertEquals("SLOT-001", reservation.appointmentSlotId());
        assertEquals("Customer A", reservation.customerName());
        assertEquals(3, service.getAvailableSlots().size());
        verify(auditService).logEvent(
                eq("BOOKING_CREATED"),
                contains("SLOT-001")
        );
    }
    @Test
    void shouldRejectDuplicateBooking() {
        service.bookAppointment("SLOT-001", "Customer A");
        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> service.bookAppointment(
                        "SLOT-001", "Customer B")
        );
        assertEquals(
                "Appointment slot is already reserved",
                exception.getMessage()
        );
    }
    @Test
    void shouldRejectInvalidSlot() {
        assertThrows(
                IllegalArgumentException.class,
                () -> service.bookAppointment(
                        "INVALID", "Customer A")
        );
    }
    @Test
    void shouldRejectBlankCustomerName() {
        assertThrows(
                IllegalArgumentException.class,
                () -> service.bookAppointment("SLOT-001", " ")
        );
    }
    @Test
    void shouldRetrieveReservation() {
        Reservation reservation =
                service.bookAppointment("SLOT-001", "Customer A");
        Reservation retrieved =
                service.getReservation(reservation.id());
        assertEquals(reservation.id(), retrieved.id());
    }
    @Test
    void shouldCancelReservationAndRestoreAvailability() {
        Reservation reservation =
                service.bookAppointment("SLOT-001", "Customer A");
        service.cancelReservation(reservation.id());
        assertEquals(4, service.getAvailableSlots().size());
        verify(auditService).logEvent(
                eq("BOOKING_CANCELLED"),
                contains(reservation.id())
        );
    }
    @Test
    void shouldAllowOnlyOneConcurrentBooking() throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        try {
            java.util.concurrent.Callable<Boolean> booking = () -> {
                ready.countDown();
                start.await();
                try {
                    service.bookAppointment(
                            "SLOT-001",
                            Thread.currentThread().getName()
                    );
                    return true;
                } catch (IllegalStateException ex) {
                    return false;
                }
            };
            Future<Boolean> first = executor.submit(booking);
            Future<Boolean> second = executor.submit(booking);
            assertTrue(ready.await(5, TimeUnit.SECONDS));
            start.countDown();
            int successfulBookings =
                    (first.get(5, TimeUnit.SECONDS) ? 1 : 0)
                            + (second.get(5, TimeUnit.SECONDS) ? 1 : 0);
            assertEquals(1, successfulBookings);
            assertEquals(1, service.getAllReservations().size());
            assertEquals(3, service.getAvailableSlots().size());
        } finally {
            start.countDown();
            executor.shutdownNow();
        }
    }
    @Test
    void shouldSaveReservationAfterBooking() {
        service.bookAppointment("SLOT-001", "Customer A");
        verify(reservationStore).save(anyList());
    }
    @Test
    void shouldRejectCancellationOfUnknownReservation() {
        assertThrows(
                IllegalArgumentException.class,
                () -> service.cancelReservation("INVALID-ID")
        );
    }
    @Test
    void shouldRejectDuplicateCancellation() {
        Reservation reservation =
                service.bookAppointment("SLOT-001", "Customer A");
        service.cancelReservation(reservation.id());
        assertThrows(
                IllegalArgumentException.class,
                () -> service.cancelReservation(reservation.id())
        );
    }
    @Test
    void shouldRejectWhitespaceOnlyCustomerName() {
        assertThrows(
                IllegalArgumentException.class,
                () -> service.bookAppointment("SLOT-001", "   ")
        );
    }
}