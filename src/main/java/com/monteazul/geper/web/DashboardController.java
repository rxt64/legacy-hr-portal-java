package com.monteazul.geper.web;

import com.monteazul.geper.service.CatalogService;
import com.monteazul.geper.service.DashboardService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class DashboardController {

    private final DashboardService dashboard;
    private final CatalogService catalog;

    public DashboardController(DashboardService dashboard, CatalogService catalog) {
        this.dashboard = dashboard;
        this.catalog = catalog;
    }

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("stats", dashboard.stats());
        model.addAttribute("deptSummary", catalog.salarySummary());
        model.addAttribute("active", "dashboard");
        return "dashboard";
    }
}
