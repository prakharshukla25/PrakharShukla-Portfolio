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
    summary: "DevOps delivery for a Know Your Business verification platform. I managed repositories, validation, and release workflows that connected developer changes with Dev, UAT, and Production deployments.",
    sections: [
      { title: "Delivery context", text: "The work covered both source control and application delivery. A change needed a clear review path in GitHub, automated build validation, and environment-specific release workflows in Azure DevOps. My responsibility was to maintain those connections so developers and QA could work through a consistent delivery process." },
      { title: "What I did", items: ["Managed GitHub repositories and branching strategies, including branch protection and pull request validation to apply checks before changes were merged.", "Built and maintained CI/CD workflows using Azure DevOps, Git, and YAML, covering build validation and release automation across Dev, UAT, and Production.", "Implemented automated quality checks alongside repository controls, making validation part of the team's normal change process.", "Worked on Azure infrastructure and Linux administration, using PowerShell automation for environment and delivery work with attention to security and cost optimization."] },
      { title: "How the pieces worked together", text: "Repository controls governed how changes entered the codebase; pipeline validation checked those changes; release workflows handled delivery into the intended environment. Keeping these responsibilities connected supported collaboration between development and QA and made deployment troubleshooting part of the release process." },
      { title: "Value delivered", text: "The practical value was a shared route from change to release: protected branches, visible validation results, and repeatable environment workflows. These controls supported code quality and deployment reliability without relying on a different set of manual steps for each release." }
    ]
  },
  finance: {
    category: "FINANCIAL SERVICES / PROFESSIONAL PROJECT",
    title: "Financial Account Opening",
    summary: "DevOps delivery for a financial account opening application. I worked on Azure DevOps pipelines, release automation, and deployment troubleshooting across Dev, UAT, and Production, including downstream system integration.",
    sections: [
      { title: "Delivery context", text: "Application delivery involved builds, tests, environment configuration, and integration with downstream systems. My work covered the route from a Git change through pipeline execution to deployment, with development and QA involved when a release or environment needed investigation." },
      { title: "What I did", items: ["Designed and maintained CI/CD pipelines using Azure DevOps, Git, and YAML to automate application builds, testing, and deployments.", "Supported delivery across Dev, UAT, and Production, connecting release automation with the configuration required by each environment.", "Managed release automation and investigated deployment issues using Docker, Kubernetes on Azure AKS, and Terraform.", "Worked with development and QA on delivery troubleshooting and supported the application's integration with downstream systems."] },
      { title: "How the tools contributed", text: "Azure DevOps and YAML defined the build, test, and deployment workflow. Docker provided the application container context; AKS provided the Azure Kubernetes environment; Terraform supported infrastructure automation. My release and troubleshooting work crossed these layers, so pipeline execution and the target environment had to be considered together." },
      { title: "Value delivered", text: "Automated build, test, and deployment steps gave the team a repeatable release process across environments. Combining that automation with deployment troubleshooting and downstream integration support helped the team work through delivery issues, connecting pipeline execution with the application's target environment and dependent systems." }
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
function restoreProjectFocus() {
  if (projectDialog.open) return;
  document.body.classList.remove("dialog-open");
  if (projectTrigger) projectTrigger.focus();
}
function closeProject() {
  projectDialog.close();
  restoreProjectFocus();
}
document.getElementById("close-project").addEventListener("click", closeProject);
projectDialog.addEventListener("click", (event) => {
  const rect = projectDialog.getBoundingClientRect();
  if (event.target === projectDialog && (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom)) closeProject();
});
projectDialog.addEventListener("close", restoreProjectFocus);

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

const navigation = [...document.querySelectorAll(".desktop-nav a")];
const navigationSections = navigation.map((link) => document.querySelector(link.getAttribute("href")));
navigation.forEach((link) => link.addEventListener("click", () => {
  navigation.forEach((item) => item.removeAttribute("aria-current"));
  link.setAttribute("aria-current", "location");
}));
let navigationFrame;
function updateNavigation() {
  navigationFrame = null;
  const marker = window.innerHeight * 0.25;
  const activeSection = navigationSections.find((section) => {
    const bounds = section.getBoundingClientRect();
    return bounds.top <= marker && bounds.bottom > marker;
  });
  navigation.forEach((link, index) => {
    if (activeSection && navigationSections[index] === activeSection) link.setAttribute("aria-current", "location");
    else link.removeAttribute("aria-current");
  });
}
function scheduleNavigationUpdate() {
  if (!navigationFrame) navigationFrame = window.requestAnimationFrame(updateNavigation);
}
window.addEventListener("scroll", scheduleNavigationUpdate, { passive: true });
window.addEventListener("resize", scheduleNavigationUpdate);
updateNavigation();
