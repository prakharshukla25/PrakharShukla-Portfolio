"use strict";

// Local interactions only: no analytics, API calls, or third-party scripts.
const menuToggle = document.querySelector(".menu-toggle");
const mobileNav = document.getElementById("mobile-nav");
function closeMenu() {
  mobileNav.hidden = true;
  menuToggle.setAttribute("aria-expanded", "false");
  menuToggle.setAttribute("aria-label", "Open navigation");
}
menuToggle.addEventListener("click", () => {
  const isOpen = menuToggle.getAttribute("aria-expanded") === "true";
  mobileNav.hidden = isOpen;
  menuToggle.setAttribute("aria-expanded", String(!isOpen));
  menuToggle.setAttribute("aria-label", isOpen ? "Open navigation" : "Close navigation");
});
mobileNav.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu));
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !mobileNav.hidden) { closeMenu(); menuToggle.focus(); }
});
document.addEventListener("click", (event) => { if (!event.target.closest(".site-header")) closeMenu(); });
window.matchMedia("(min-width: 701px)").addEventListener("change", (event) => { if (event.matches) closeMenu(); });

document.getElementById("year").textContent = new Date().getFullYear();

// A clearly labelled simulation. It never starts a real deployment.
const runButton = document.getElementById("run-pipeline");
const pipelineStatus = document.getElementById("pipeline-status");
const stages = [...document.querySelectorAll("[data-stage]")];
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const stageMessages = ["Checking out the change…", "Validating site & links…", "Packaging the artifact…", "Deploying the demo…"];
const delay = (ms) => new Promise((resolve) => window.setTimeout(resolve, ms));
let running = false;
runButton.addEventListener("click", async () => {
  if (running) return;
  running = true;
  runButton.disabled = true;
  runButton.textContent = "Running…";
  stages.forEach((stage, index) => { stage.classList.remove("active", "complete"); stage.querySelector(".stage-dot").textContent = `0${index + 1}`; });
  for (let index = 0; index < stages.length; index += 1) {
    stages[index].classList.add("active");
    pipelineStatus.textContent = stageMessages[index];
    await delay(reducedMotion.matches ? 120 : 750);
    stages[index].classList.remove("active");
    stages[index].classList.add("complete");
    stages[index].querySelector(".stage-dot").textContent = "✓";
  }
  pipelineStatus.textContent = "All stages passed. Demo complete.";
  runButton.textContent = "↻ Run again";
  runButton.disabled = false;
  running = false;
});

const projects = {
  verikyb: {
    category: "BUSINESS VERIFICATION / PROFESSIONAL PROJECT",
    title: "VeriKYB",
    summary: "Delivery engineering for a Know Your Business verification platform. My work connected repository governance, automated validation, and deployment workflows across Dev, UAT, and Production.",
    sections: [
      { title: "The engineering focus", text: "Create a consistent route from a developer’s change to a release, with branch protection and automated checks built into the process." },
      { title: "My contribution", items: ["Managed GitHub repositories and branching strategies, with CI/CD pipelines built using Azure DevOps, Git, and YAML.", "Automated build validation and release workflows across Dev, UAT, and Production environments.", "Implemented Git branch protection, pull request validation, and automated quality checks.", "Worked with Azure infrastructure, Linux administration, and PowerShell automation, with attention to security and cost optimization."] },
      { title: "Why it matters", text: "Consistent validation and environment workflows support code quality, deployment reliability, and team collaboration. These are the outcomes behind my delivery decisions." }
    ]
  },
  finance: {
    category: "FINANCIAL SERVICES / PROFESSIONAL PROJECT",
    title: "Financial Account Opening",
    summary: "CI/CD and cloud delivery for a financial account opening application, covering automated builds, testing, deployments, and downstream system integration.",
    sections: [
      { title: "The engineering focus", text: "Support reliable application delivery across environments, while keeping release automation and deployment troubleshooting part of the same workflow." },
      { title: "My contribution", items: ["Designed and maintained CI/CD pipelines with Azure DevOps, Git, and YAML.", "Automated application builds, testing, and deployments across Dev, UAT, and Production.", "Managed release automation and investigated deployment issues using Docker, Kubernetes on Azure AKS, and Terraform.", "Supported application delivery and seamless integration with downstream systems."] },
      { title: "The approach", text: "Combine infrastructure automation, container orchestration, and repeatable release workflows so that delivery is a process teams can understand and maintain." }
    ]
  }
};
const projectDialog = document.getElementById("project-dialog");
const dialogBody = document.getElementById("dialog-body");
let projectTrigger;
document.querySelectorAll("[data-project]").forEach((button) => {
  button.addEventListener("click", () => {
    const project = projects[button.dataset.project];
    if (!project) return;
    projectTrigger = button;
    document.getElementById("dialog-category").textContent = project.category;
    document.getElementById("dialog-title").textContent = project.title;
    document.getElementById("dialog-summary").textContent = project.summary;
    dialogBody.replaceChildren();
    project.sections.forEach((section) => {
      const wrapper = document.createElement("div");
      wrapper.className = "dialog-body-section";
      const heading = document.createElement("h3");
      heading.textContent = section.title;
      wrapper.append(heading);
      if (section.text) { const paragraph = document.createElement("p"); paragraph.textContent = section.text; wrapper.append(paragraph); }
      if (section.items) {
        const list = document.createElement("ul");
        section.items.forEach((text) => { const item = document.createElement("li"); item.textContent = text; list.append(item); });
        wrapper.append(list);
      }
      dialogBody.append(wrapper);
    });
    projectDialog.showModal();
    document.body.classList.add("dialog-open");
    projectDialog.scrollTop = 0;
    document.getElementById("close-project").focus();
  });
});
document.getElementById("close-project").addEventListener("click", () => projectDialog.close());
projectDialog.addEventListener("click", (event) => {
  const rect = projectDialog.getBoundingClientRect();
  if (event.target === projectDialog && (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom)) projectDialog.close();
});
projectDialog.addEventListener("close", () => { document.body.classList.remove("dialog-open"); if (projectTrigger) projectTrigger.focus(); });

const copyButton = document.getElementById("copy-email");
const copyStatus = document.getElementById("copy-status");
let copyTimer;
copyButton.addEventListener("click", async () => {
  window.clearTimeout(copyTimer);
  copyButton.disabled = true;
  copyStatus.textContent = "Copying email…";
  let clipboardTimeout;
  try {
    await Promise.race([
      navigator.clipboard.writeText("pshukla2019@gmail.com"),
      new Promise((_, reject) => { clipboardTimeout = window.setTimeout(() => reject(new Error("Clipboard unavailable")), 2000); })
    ]);
    copyStatus.textContent = "Email copied!";
  } catch {
    copyStatus.textContent = "Select the email address to copy it.";
  } finally {
    window.clearTimeout(clipboardTimeout);
    copyButton.disabled = false;
  }
  copyTimer = window.setTimeout(() => { copyStatus.textContent = ""; }, 5000);
});

if ("IntersectionObserver" in window) {
  const navigation = [...document.querySelectorAll(".desktop-nav a")];
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      const link = navigation.find((item) => item.getAttribute("href") === `#${entry.target.id}`);
      if (!link) return;
      if (entry.isIntersecting) { navigation.forEach((item) => item.removeAttribute("aria-current")); link.setAttribute("aria-current", "location"); }
      else if (link.hasAttribute("aria-current")) link.removeAttribute("aria-current");
    });
  }, { rootMargin: "-15% 0px -35% 0px", threshold: 0 });
  ["work", "experience", "stack"].forEach((id) => observer.observe(document.getElementById(id)));
}
