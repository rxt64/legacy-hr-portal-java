package com.monteazul.geper.web;

import com.monteazul.geper.domain.Department;
import com.monteazul.geper.service.CatalogService;
import com.monteazul.geper.service.EmployeeService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequestMapping("/departamentos")
public class DepartmentController {

    private final CatalogService catalog;
    private final EmployeeService employees;

    public DepartmentController(CatalogService catalog, EmployeeService employees) {
        this.catalog = catalog;
        this.employees = employees;
    }

    /** Department list with the per-department salary summary (Oracle aggregates). */
    @GetMapping
    public String list(Model model) {
        model.addAttribute("summary", catalog.salarySummary());
        model.addAttribute("active", "departamentos");
        return "departments/list";
    }

    @GetMapping("/{id}")
    public String detail(@PathVariable int id, Model model) {
        Department d = catalog.department(id);
        if (d == null) {
            return "redirect:/departamentos";
        }
        model.addAttribute("department", d);
        model.addAttribute("members", employees.search(null, id, null));
        model.addAttribute("active", "departamentos");
        return "departments/detail";
    }

    @GetMapping("/nuevo")
    public String newForm(Model model) {
        model.addAttribute("department", new Department());
        model.addAttribute("mode", "create");
        model.addAttribute("active", "departamentos");
        return "departments/form";
    }

    @PostMapping
    public String create(@ModelAttribute("department") Department department, RedirectAttributes ra) {
        int id = catalog.createDepartment(department);
        ra.addFlashAttribute("flash", "Departamento creado con numero " + id);
        return "redirect:/departamentos/" + id;
    }

    @GetMapping("/{id}/editar")
    public String editForm(@PathVariable int id, Model model) {
        Department d = catalog.department(id);
        if (d == null) {
            return "redirect:/departamentos";
        }
        model.addAttribute("department", d);
        model.addAttribute("mode", "edit");
        model.addAttribute("active", "departamentos");
        return "departments/form";
    }

    @PostMapping("/{id}")
    public String update(@PathVariable int id, @ModelAttribute("department") Department department,
                        RedirectAttributes ra) {
        department.setDepartmentId(id);
        catalog.updateDepartment(department);
        ra.addFlashAttribute("flash", "Departamento actualizado");
        return "redirect:/departamentos/" + id;
    }
}
