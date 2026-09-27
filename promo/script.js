(() => {
  const root = document.documentElement;
  const progress = document.querySelector('.read-progress span');
  const themeButton = document.querySelector('.theme-toggle');
  const tocLinks = [...document.querySelectorAll('.toc a')];
  const sections = tocLinks
    .map((link) => document.querySelector(link.getAttribute('href')))
    .filter(Boolean);
  const toast = document.querySelector('.toast');
  const modal = document.querySelector('.image-modal');
  const modalImage = modal?.querySelector('img');
  let toastTimer;

  const storedTheme = localStorage.getItem('pvr-theme');
  if (storedTheme === 'dark' || storedTheme === 'light') {
    root.dataset.theme = storedTheme;
  } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
    root.dataset.theme = 'light';
  }

  themeButton?.addEventListener('click', () => {
    root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('pvr-theme', root.dataset.theme);
  });

  const updateProgress = () => {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight;
    const percent = scrollable > 0 ? Math.min(100, (window.scrollY / scrollable) * 100) : 0;
    progress.style.height = `${percent}%`;
  };

  const updateActiveSection = () => {
    const marker = window.scrollY + Math.min(240, window.innerHeight * 0.32);
    const visible = [...sections].reverse().find((section) => section.offsetTop <= marker) || sections[0];
    tocLinks.forEach((link) => {
      const active = link.getAttribute('href') === `#${visible.id}`;
      link.classList.toggle('active', active);
      if (active) link.setAttribute('aria-current', 'true');
      else link.removeAttribute('aria-current');
    });
  };

  window.addEventListener('scroll', () => {
    updateProgress();
    updateActiveSection();
  }, { passive: true });
  updateProgress();
  updateActiveSection();

  const showToast = (message = 'Скопировано') => {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 1800);
  };

  document.querySelectorAll('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const value = button.dataset.copy;
      try {
        await navigator.clipboard.writeText(value);
        showToast();
      } catch {
        const area = document.createElement('textarea');
        area.value = value;
        area.style.position = 'fixed';
        area.style.opacity = '0';
        document.body.append(area);
        area.select();
        document.execCommand('copy');
        area.remove();
        showToast();
      }
    });
  });

  const tabButtons = [...document.querySelectorAll('[data-tab]')];
  const panels = [...document.querySelectorAll('[data-panel]')];
  tabButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const selected = button.dataset.tab;
      tabButtons.forEach((item) => item.setAttribute('aria-selected', String(item === button)));
      panels.forEach((panel) => {
        const active = panel.dataset.panel === selected;
        panel.classList.toggle('active', active);
        panel.hidden = !active;
      });
    });
  });

  document.querySelectorAll('.image-button').forEach((button) => {
    button.addEventListener('click', () => {
      if (!modal || !modalImage) return;
      const source = button.dataset.image;
      const preview = button.querySelector('img');
      modalImage.src = source;
      modalImage.alt = preview?.alt || '';
      modal.showModal();
    });
  });

  modal?.querySelector('.modal-close')?.addEventListener('click', () => modal.close());
  modal?.addEventListener('click', (event) => {
    if (event.target === modal) modal.close();
  });
})();
