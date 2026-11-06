package com.monteazul.geper;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * GEPER - Gestion de Personal y Puestos.
 * Corporacion Regional Monte Azul (institucion ficticia).
 *
 * Legacy server-rendered intranet. Entry point for the Spring Boot host.
 */
@SpringBootApplication
public class GeperApplication {

    public static void main(String[] args) {
        SpringApplication.run(GeperApplication.class, args);
    }
}
