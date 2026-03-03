// ===== WolfeWaveSignals Image Carousel =====
// Multi-image lightbox with slider, dots, arrows, swipe support

(function() {
  const carouselHTML = `
  <style>
  .carousel-overlay {
    display: none; position: fixed; inset: 0; z-index: 10000;
    background: rgba(0,0,0,0.92); align-items: center; justify-content: center;
    flex-direction: column; padding: 20px;
  }
  .carousel-overlay.active { display: flex; }
  .carousel-close {
    position: absolute; top: 16px; right: 16px;
    width: 44px; height: 44px; border-radius: 50%;
    background: rgba(255,255,255,0.15); border: none;
    color: #fff; font-size: 24px; cursor: pointer;
    display: flex; align-items: center; justify-content: center;
    z-index: 10001; transition: background 0.2s;
  }
  .carousel-close:hover { background: rgba(255,255,255,0.3); }
  .carousel-container {
    position: relative; width: 100%; max-width: 1200px;
    display: flex; align-items: center; justify-content: center;
    flex: 1; min-height: 0;
  }
  .carousel-img {
    max-width: 95vw; max-height: 80vh; border-radius: 12px;
    object-fit: contain; user-select: none;
  }
  .carousel-arrow {
    position: absolute; top: 50%; transform: translateY(-50%);
    width: 48px; height: 48px; border-radius: 50%;
    background: rgba(255,255,255,0.15); border: none;
    color: #fff; font-size: 22px; cursor: pointer;
    display: flex; align-items: center; justify-content: center;
    transition: background 0.2s; z-index: 10001;
  }
  .carousel-arrow:hover { background: rgba(255,255,255,0.3); }
  .carousel-arrow.prev { left: 16px; }
  .carousel-arrow.next { right: 16px; }
  .carousel-dots {
    display: flex; gap: 8px; margin-top: 16px; justify-content: center;
  }
  .carousel-dot {
    width: 10px; height: 10px; border-radius: 50%;
    background: rgba(255,255,255,0.3); border: none;
    cursor: pointer; transition: all 0.2s; padding: 0;
  }
  .carousel-dot.active { background: #10b981; transform: scale(1.3); }
  .carousel-label {
    color: rgba(255,255,255,0.7); font-size: 13px; margin-top: 8px;
    font-family: 'Space Grotesk', system-ui, sans-serif;
  }
  @media (max-width: 768px) {
    .carousel-arrow { width: 36px; height: 36px; font-size: 18px; }
    .carousel-arrow.prev { left: 8px; }
    .carousel-arrow.next { right: 8px; }
  }
  </style>
  <div class="carousel-overlay" id="carousel-overlay">
    <button class="carousel-close" onclick="closeCarousel()">&times;</button>
    <div class="carousel-container" id="carousel-container">
      <button class="carousel-arrow prev" onclick="carouselPrev()">&#8249;</button>
      <img class="carousel-img" id="carousel-img" src="" alt="Signal Chart">
      <button class="carousel-arrow next" onclick="carouselNext()">&#8250;</button>
    </div>
    <div class="carousel-dots" id="carousel-dots"></div>
    <div class="carousel-label" id="carousel-label"></div>
  </div>`;

  // Inject into body
  const div = document.createElement('div');
  div.innerHTML = carouselHTML;
  document.body.appendChild(div);

  // State
  let carouselImages = [];
  let carouselIndex = 0;
  let touchStartX = 0;

  // Type labels
  const typeLabels = {
    'detect': 'Erkennung',
    'entry': 'Einstieg',
    'latest': 'Aktuell',
    'display_photo': 'Anzeige'
  };

  // Open carousel for a wedge_id
  window.openCarousel = function(wedgeId) {
    // Get images from global imageMap (set by the page)
    const imgs = window._carouselImageMap?.[wedgeId] || [];
    if (!imgs.length) return;

    carouselImages = imgs.map(img => ({
      url: img.url && img.url.startsWith('http') ? img.url : `${STORAGE_URL}/${img.url}`,
      type: img.type,
      label: typeLabels[img.type] || img.type
    }));
    carouselIndex = 0;
    updateCarousel();
    document.getElementById('carousel-overlay').classList.add('active');
    document.body.style.overflow = 'hidden';
  };

  window.closeCarousel = function() {
    document.getElementById('carousel-overlay').classList.remove('active');
    document.body.style.overflow = '';
  };

  window.carouselNext = function() {
    if (carouselImages.length === 0) return;
    carouselIndex = (carouselIndex + 1) % carouselImages.length;
    updateCarousel();
  };

  window.carouselPrev = function() {
    if (carouselImages.length === 0) return;
    carouselIndex = (carouselIndex - 1 + carouselImages.length) % carouselImages.length;
    updateCarousel();
  };

  function updateCarousel() {
    const img = document.getElementById('carousel-img');
    const dots = document.getElementById('carousel-dots');
    const label = document.getElementById('carousel-label');
    if (!img || !carouselImages.length) return;

    const current = carouselImages[carouselIndex];
    img.src = current.url;
    label.textContent = `${current.label} (${carouselIndex + 1}/${carouselImages.length})`;

    dots.innerHTML = carouselImages.map((_, i) =>
      `<button class="carousel-dot ${i === carouselIndex ? 'active' : ''}" onclick="carouselGoTo(${i})"></button>`
    ).join('');
  }

  window.carouselGoTo = function(idx) {
    carouselIndex = idx;
    updateCarousel();
  };

  // Keyboard navigation
  document.addEventListener('keydown', e => {
    const overlay = document.getElementById('carousel-overlay');
    if (!overlay || !overlay.classList.contains('active')) return;
    if (e.key === 'ArrowRight') carouselNext();
    else if (e.key === 'ArrowLeft') carouselPrev();
    else if (e.key === 'Escape') closeCarousel();
  });

  // Swipe support
  const container = document.getElementById('carousel-container');
  if (container) {
    container.addEventListener('touchstart', e => {
      touchStartX = e.touches[0].clientX;
    }, { passive: true });
    container.addEventListener('touchend', e => {
      const diff = touchStartX - e.changedTouches[0].clientX;
      if (Math.abs(diff) > 50) {
        if (diff > 0) carouselNext();
        else carouselPrev();
      }
    }, { passive: true });
  }

  // Click outside to close
  document.getElementById('carousel-overlay')?.addEventListener('click', e => {
    if (e.target.id === 'carousel-overlay') closeCarousel();
  });
})();
