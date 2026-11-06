package com.monteazul.geper.web;

import com.monteazul.geper.domain.Employee;
import com.monteazul.geper.service.CatalogService;
import com.monteazul.geper.service.EmployeeService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import jakarta.validation.Valid;
import java.math.BigDecimal;

@Controller
@RequestMapping("/empleados")
public class EmployeeController {

    private final EmployeeService employees;
    private final CatalogService catalog;

    public EmployeeController(EmployeeService employees, CatalogService catalog) {
        this.employees = employees;
        this.catalog = catalog;
    }

    private void addCatalogs(Model model) {
        model.addAttribute("jobs", catalog.jobs());
        model.addAttribute("departments", catalog.departments());
    }

    /** List + personnel search by name / department / job (parameterized). */
    @GetMapping
    public String list(@RequestParam(required = false) String name,
                       @RequestParam(required = false) Integer departmentId,
                       @RequestParam(required = false) String jobId,
                       Model model) {
        model.addAttribute("results", employees.search(name, departmentId, jobId));
        model.addAttribute("name", name);
        model.addAttribute("departmentId", departmentId);
        model.addAttribute("jobId", jobId);
        addCatalogs(model);
        model.addAttribute("active", "empleados");
        return "employees/list";
    }

    @GetMapping("/{id}")
    public String detail(@PathVariable int id, Model model) {
        Employee e = employees.findById(id);
        if (e == null) {
            return "redirect:/empleados";
        }
        model.addAttribute("employee", e);
        model.addAttribute("history", employees.history(id));
        model.addAttribute("active", "empleados");
        return "employees/detail";
    }

    @GetMapping("/nuevo")
    public String newForm(Model model) {
        model.addAttribute("employee", new Employee());
        addCatalogs(model);
        model.addAttribute("mode", "create");
        model.addAttribute("active", "empleados");
        return "employees/form";
    }

    @PostMapping
    public String create(@Valid @ModelAttribute("employee") Employee employee,
                         BindingResult binding, Model model, RedirectAttributes ra) {
        if (binding.hasErrors()) {
            addCatalogs(model);
            model.addAttribute("mode", "create");
            model.addAttribute("active", "empleados");
            return "employees/form";
        }
        int id = employees.create(employee);
        ra.addFlashAttribute("flash", "Empleado creado con numero " + id);
        return "redirect:/empleados/" + id;
    }

    @GetMapping("/{id}/editar")
    public String editForm(@PathVariable int id, Model model) {
        Employee e = employees.findById(id);
        if (e == null) {
            return "redirect:/empleados";
        }
        model.addAttribute("employee", e);
        addCatalogs(model);
        model.addAttribute("mode", "edit");
        model.addAttribute("active", "empleados");
        return "employees/form";
    }

    @PostMapping("/{id}")
    public String update(@PathVariable int id,
                        @Valid @ModelAttribute("employee") Employee employee,
                        BindingResult binding, Model model, RedirectAttributes ra) {
        if (binding.hasErrors()) {
            addCatalogs(model);
            model.addAttribute("mode", "edit");
            model.addAttribute("active", "empleados");
            return "employees/form";
        }
        employee.setEmployeeId(id);
        employees.update(employee);
        ra.addFlashAttribute("flash", "Empleado actualizado");
        return "redirect:/empleados/" + id;
    }

    /** Salary change (no history entry). */
    @PostMapping("/{id}/salario")
    public String changeSalary(@PathVariable int id, @RequestParam BigDecimal salary,
                              RedirectAttributes ra) {
        employees.changeSalary(id, salary);
        ra.addFlashAttribute("flash", "Salario actualizado");
        return "redirect:/empleados/" + id;
    }

    /** Job and/or department change (creates job history via the trigger). */
    @PostMapping("/{id}/asignacion")
    public String changeAssignment(@PathVariable int id,
                                   @RequestParam String jobId,
                                   @RequestParam(required = false) Integer departmentId,
                                   RedirectAttributes ra) {
        employees.changeAssignment(id, jobId, departmentId);
        ra.addFlashAttribute("flash", "Asignacion actualizada; historial registrado");
        return "redirect:/empleados/" + id;
    }

    /**
     * Normal observations update. The stored value is rendered with HTML
     * escaping on the employee card (see employees/detail.html), so this path
     * is not XSS-vulnerable. The deliberately unsafe rendering lives only in
     * the lab view (SECURITY-LAB JAVA-XSS-01).
     */
    @PostMapping("/{id}/observaciones")
    public String updateObservations(@PathVariable int id, @RequestParam String observations,
                                     RedirectAttributes ra) {
        employees.updateObservations(id, observations);
        ra.addFlashAttribute("flash", "Observaciones actualizadas");
        return "redirect:/empleados/" + id;
    }
}
