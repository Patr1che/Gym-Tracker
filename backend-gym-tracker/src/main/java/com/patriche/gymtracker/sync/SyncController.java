package com.patriche.gymtracker.sync;

import com.patriche.gymtracker.sync.SyncDtos.SyncRequest;
import com.patriche.gymtracker.sync.SyncDtos.SyncResponse;
import com.patriche.gymtracker.user.CurrentUser;
import jakarta.validation.Valid;
import java.time.Instant;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/sync")
class SyncController {

    private final SyncService sync;

    SyncController(SyncService sync) {
        this.sync = sync;
    }

    @PostMapping
    SyncResponse sync(@Valid @RequestBody SyncRequest req) {
        return sync.sync(CurrentUser.id(), req, Instant.now());
    }
}
