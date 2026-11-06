package com.monteazul.geper.lab;

import com.monteazul.geper.domain.Employee;
import com.monteazul.geper.service.EmployeeService;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.List;
import java.util.Map;

/**
 * Vulnerability-lab routes. Registered ONLY when geper.labs.enabled=true
 * (ENABLE_VULNERABILITY_LABS=true). With the labs off this controller is not
 * a bean, so /lab/** returns 404. The {@link com.monteazul.geper.config.LabLoopbackFilter}
 * additionally restricts every /lab/** path to loopback callers.
 *
 * Contains SECURITY-LAB JAVA-SQLI-01 and SECURITY-LAB JAVA-XSS-01.
 */
@Controller
@RequestMapping("/lab")
@ConditionalOnProperty(prefix = "geper.labs", name = "enabled", havingValue = "true")
public class LabController {

    private final LabSearchRepository labSearch;
    private final EmployeeService employees;

    public LabController(LabSearchRepository labSearch, EmployeeService employees) {
        this.labSearch = labSearch;
        this.employees = employees;
    }

    @GetMapping
    public String index(Model model) {
        model.addAttribute("active", "lab");
        return "lab/index";
    }

    // ---------------------------------------------------------------
    // SECURITY-LAB JAVA-SQLI-01 — SQL injection in a JDBC Statement
    // ---------------------------------------------------------------
    @GetMapping("/sqli")
    public String sqli(@RequestParam(required = false, defaultValue = "") String term, Model model) {
        model.addAttribute("term", term);
        if (!term.isEmpty()) {
            List<Map<String, Object>> rows = labSearch.vulnerableSearch(term);
            model.addAttribute("rows", rows);
            model.addAttribute("sql", labSearch.buildSql(term));
        }
        model.addAttribute("active", "lab");
        return "lab/sqli";
    }

    // ---------------------------------------------------------------
    // SECURITY-LAB JAVA-XSS-01 — stored XSS in employee observations
    // ---------------------------------------------------------------
    @GetMapping("/xss")
    public String xssForm(@RequestParam(required = false) Integer employeeId, Model model) {
        model.addAttribute("employees", employees.findAll());
        if (employeeId != null) {
            model.addAttribute("employee", employees.findById(employeeId));
        }
        model.addAttribute("active", "lab");
        return "lab/xss";
    }

    /** Stores the raw observation text (written via the normal app account). */
    @PostMapping("/xss")
    public String xssStore(@RequestParam int employeeId, @RequestParam String observations,
                           RedirectAttributes ra) {
        employees.updateObservations(employeeId, observations);
        ra.addFlashAttribute("flash", "Observacion almacenada para el empleado " + employeeId);
        return "redirect:/lab/xss/view/" + employeeId;
    }

    /**
     * Vulnerable rendering: the stored observation is emitted WITHOUT HTML
     * escaping (lab/view.html uses th:utext). The normal employee card
     * (employees/detail.html) renders the same field escaped with th:text.
     */
    @GetMapping("/xss/view/{employeeId}")
    public String xssView(@PathVariable int employeeId, Model model) {
        Employee e = employees.findById(employeeId);
        model.addAttribute("employee", e);
        model.addAttribute("active", "lab");
        return "lab/view";
    }

    /**
     * Convenience reset for the single employee used in the exercise. For a
     * full restore of the seeded observations, run db/reset/90_reset_lab.sql.
     */
    @PostMapping("/xss/reset/{employeeId}")
    public String xssReset(@PathVariable int employeeId, RedirectAttributes ra) {
        employees.updateObservations(employeeId, null);
        ra.addFlashAttribute("flash", "Observacion del empleado " + employeeId
                + " restablecida (NULL). Para restaurar todo el baseline use db/reset/90_reset_lab.sql");
        return "redirect:/lab/xss?employeeId=" + employeeId;
    }
}
