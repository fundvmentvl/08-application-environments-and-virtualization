package concurrent_reservation_service.service;
import concurrent_reservation_service.audit.AsyncAuditService;
import concurrent_reservation_service.model.AppointmentSlot;
import concurrent_reservation_service.model.Reservation;
import concurrent_reservation_service.persistence.ReservationStore;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ReservationService {
    private final Map<String, AppointmentSlot> slots = new HashMap<>();
    private final Map<String, Reservation> reservations = new HashMap<>();
    private final Object bookingLock = new Object();
    private final AsyncAuditService auditService;
    private final ReservationStore reservationStore;

    public ReservationService(
            AsyncAuditService auditService,
            ReservationStore reservationStore) {
        this.auditService = auditService;
        this.reservationStore = reservationStore;
        LocalDate date = LocalDate.now().plusDays(1);
        addSlot("SLOT-001", date, LocalTime.of(9, 0));
        addSlot("SLOT-002", date, LocalTime.of(9, 30));
        addSlot("SLOT-003", date, LocalTime.of(10, 0));
        addSlot("SLOT-004", date, LocalTime.of(10, 30));
        for (Reservation reservation : reservationStore.load()) {
            if (reservations.putIfAbsent(
                    reservation.id(), reservation) != null) {
                throw new IllegalStateException(
                        "Duplicate reservation ID in stored data");
            }
        }
    }

    private void addSlot(
            String id,
            LocalDate date,
            LocalTime start) {
        slots.put(id, new AppointmentSlot(
                id,
                date,
                start,
                start.plusMinutes(30)
        ));
    }

    public List<AppointmentSlot> getAvailableSlots() {
        synchronized (bookingLock) {
            Set<String> reservedSlotIds = reservations.values()
                    .stream()
                    .map(Reservation::appointmentSlotId)
                    .collect(Collectors.toSet());
            return slots.values().stream()
                    .filter(slot -> !reservedSlotIds.contains(slot.id()))
                    .sorted(Comparator.comparing(
                            AppointmentSlot::startTime))
                    .toList();
        }
    }

    public Reservation bookAppointment(
            String slotId,
            String customerName) {
        if (slotId == null || slotId.isBlank()) {
            throw new IllegalArgumentException(
                    "Appointment slot ID is required");
        }
        if (customerName == null || customerName.isBlank()) {
            throw new IllegalArgumentException(
                    "Customer name is required");
        }
        Reservation reservation;
        synchronized (bookingLock) {
            if (!slots.containsKey(slotId)) {
                throw new IllegalArgumentException(
                        "Appointment slot does not exist");
            }
            boolean alreadyBooked = reservations.values().stream()
                    .anyMatch(existing ->
                            existing.appointmentSlotId().equals(slotId));
            if (alreadyBooked) {
                throw new IllegalStateException(
                        "Appointment slot is already reserved");
            }
            reservation = new Reservation(
                    UUID.randomUUID().toString(),
                    slotId,
                    customerName.trim(),
                    LocalDateTime.now()
            );
            reservations.put(reservation.id(), reservation);
            try {
                reservationStore.save(
                        new ArrayList<>(reservations.values()));
            } catch (RuntimeException e) {
                reservations.remove(reservation.id());
                throw e;
            }
        }
        auditService.logEvent(
                "BOOKING_CREATED",
                "Reservation ID: " + reservation.id()
                        + ", Slot: " + slotId
        );
        return reservation;
    }

    public Reservation getReservation(String reservationId) {
        Reservation reservation = reservations.get(reservationId);
        if (reservation == null) {
            throw new IllegalArgumentException(
                    "Reservation not found");
        }
        return reservation;
    }
    public void cancelReservation(String reservationId) {
        synchronized (bookingLock) {
            Reservation removed = reservations.remove(reservationId);
            if (removed == null) {
                throw new IllegalArgumentException(
                        "Reservation not found");
            }
            try {
                reservationStore.save(
                        new ArrayList<>(reservations.values()));
            } catch (RuntimeException e) {
                reservations.put(reservationId, removed);
                throw e;
            }
        }
        auditService.logEvent(
                "BOOKING_CANCELLED",
                "Reservation ID: " + reservationId
        );
    }
    public List<Reservation> getAllReservations() {
        synchronized (bookingLock) {
            return new ArrayList<>(reservations.values());
        }
    }
}