package com.monteazul.geper.web;

import com.monteazul.geper.domain.Job;
import com.monteazul.geper.service.CatalogService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequestMapping("/puestos")
public class JobController {

    private final CatalogService catalog;

    public JobController(CatalogService catalog) {
        this.catalog = catalog;
    }

    @GetMapping
    public String list(Model model) {
        model.addAttribute("jobs", catalog.jobs());
        model.addAttribute("active", "puestos");
        return "jobs/list";
    }

    @GetMapping("/{id}/editar")
    public String editForm(@PathVariable String id, Model model) {
        Job j = catalog.job(id);
        if (j == null) {
            return "redirect:/puestos";
        }
        model.addAttribute("job", j);
        model.addAttribute("active", "puestos");
        return "jobs/form";
    }

    @PostMapping("/{id}")
    public String update(@PathVariable String id, @ModelAttribute("job") Job job,
                        RedirectAttributes ra) {
        job.setJobId(id);
        catalog.updateJob(job);
        ra.addFlashAttribute("flash", "Puesto actualizado");
        return "redirect:/puestos";
    }
}
