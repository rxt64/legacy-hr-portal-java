package com.monteazul.geper.config;

import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ModelAttribute;

/**
 * Exposes the lab state to every view so the shared layout can render the
 * "Laboratorio vulnerable activo" banner when, and only when, the labs are on.
 */
@ControllerAdvice
public class GlobalModelAttributes {

    private final LabProperties labs;

    public GlobalModelAttributes(LabProperties labs) {
        this.labs = labs;
    }

    @ModelAttribute("labsEnabled")
    public boolean labsEnabled() {
        return labs.isEnabled();
    }
}
