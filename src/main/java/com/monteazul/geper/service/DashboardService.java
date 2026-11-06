package com.monteazul.geper.service;

import com.monteazul.geper.domain.DashboardStats;
import com.monteazul.geper.repository.DashboardRepository;
import org.springframework.stereotype.Service;

@Service
public class DashboardService {

    private final DashboardRepository dashboard;

    public DashboardService(DashboardRepository dashboard) {
        this.dashboard = dashboard;
    }

    public DashboardStats stats() { return dashboard.load(); }
}
