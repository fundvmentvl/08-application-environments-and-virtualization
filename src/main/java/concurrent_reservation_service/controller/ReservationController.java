package concurrent_reservation_service.controller;
import concurrent_reservation_service.model.AppointmentSlot;
import concurrent_reservation_service.model.Reservation;
import concurrent_reservation_service.service.ReservationService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController

@RequestMapping("/api")

public class ReservationController {
    private final ReservationService reservationService;
    public ReservationController(ReservationService reservationService) {
        this.reservationService = reservationService;
    }

    @GetMapping("/appointments")
    public List<AppointmentSlot> getAvailableAppointments() {
        return reservationService.getAvailableSlots();
    }

    @PostMapping("/reservations")
    public ResponseEntity<Reservation> createReservation(
            @RequestBody BookingRequest request) {
        Reservation reservation = reservationService.bookAppointment(
                request.slotId(),
                request.customerName()

        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(reservation);
    }

    @GetMapping("/reservations/{id}")
    public Reservation getReservation(@PathVariable String id) {
        return reservationService.getReservation(id);
    }

    @DeleteMapping("/reservations/{id}")
    public ResponseEntity<Void> cancelReservation(@PathVariable String id) {
        reservationService.cancelReservation(id);
        return ResponseEntity.noContent().build();
    }

    public record BookingRequest(
            String slotId,
            String customerName
    ) {

    }
}
