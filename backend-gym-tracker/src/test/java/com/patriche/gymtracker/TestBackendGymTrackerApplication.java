package com.patriche.gymtracker;

import org.springframework.boot.SpringApplication;

public class TestBackendGymTrackerApplication {

	public static void main(String[] args) {
		SpringApplication.from(BackendGymTrackerApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
