<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Krayv Shop</title>
<script src="https://telegram.org/js/telegram-web-app.js"></script>
<style>
  * { box-sizing: border-box; transition: background-color 0.3s ease, color 0.3s ease; }
  :root {
    --bg: #ffffff; --text: #000000; --card-bg: #f5f5f7;
    --card-border: rgba(0,0,0,0.08); --muted: #888;
    --accent: #2481cc; --accent-text: #ffffff;
    --overlay: rgba(0,0,0,0.5); --qty-bg: #e5e5e5;
    --remove-bg: #ffdddd; --remove-text: #c00; --divider: #eee;
    --green: #22c55e;
  }
  body.dark {
    --bg: #0f0f14; --text: #ffffff; --card-bg: #1c1c22;
    --card-border: rgba(255,255,255,0.08); --muted: #999;
    --accent: #2481cc; --accent-text: #ffffff;
    --overlay: rgba(0,0,0,0.7); --qty-bg: #2c2c33;
    --remove-bg: #4a1f1f; --remove-text: #ff8888; --divider: #2a2a33;
  }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg); color: var(--text);
    padding: 16px; padding-top: 60px; padding-bottom: 100px; min-height: 100vh;
  }
  .theme-toggle {
    position: fixed; top: 14px; right: 14px;
    width: 48px; height: 28px; border-radius: 14px;
    background: var(--card-bg); border: 1px solid var(--card-border);
    cursor: pointer; z-index: 200;
    display: flex; align-items: center; padding: 3px;
  }
  .theme-toggle .knob {
    width: 22px; height: 22px; border-radius: 50%;
    background: var(--accent); display: flex; align-items: center;
    justify-content: center; font-size: 12px;
    transition: transform 0.35s cubic-bezier(0.4, 0, 0.2, 1);
  }
  body.dark .theme-toggle .knob { transform: translateX(20px); }
  .shop-title {
    font-size: 26px; font-weight: 800; color: #2481cc;
    margin: 0 0 14px 0; letter-spacing: 0.5px;
  }

  /* Вкладки */
  .tabs {
    display: flex;
    gap: 8px;
    margin-bottom: 18px;
    border-bottom: 1px solid var(--divider);
    padding-bottom: 0;
  }
  .tab {
    flex: 1;
    padding: 10px 8px;
    text-align: center;
    font-size: 14px;
    font-weight: 600;
    color: var(--muted);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition: color 0.2s ease, border-color 0.2s ease;
  }
  .tab.active {
    color: var(--accent);
    border-bottom-color: var(--accent);
  }

  /* Содержимое вкладок */
  .tab-content { display: none; }
  .tab-content.active { display: block; }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 12px;
  }
  .card {
    border: 1px solid var(--card-border); border-radius: 12px;
    padding: 10px; background: var(--card-bg);
    display: flex; flex-direction: column;
  }
  .card-img-wrap {
    width: 100%; aspect-ratio: 1 / 1; overflow: hidden;
    border-radius: 8px; margin-bottom: 8px; background: #000;
  }
  .card img {
    width: 100%; height: 100%; object-fit: cover; display: block;
  }
  .card h3 { font-size: 15px; margin: 0 0 4px 0; }
  .card .desc { font-size: 12px; color: var(--muted); margin: 0 0 6px 0; flex: 1; }
  .card .price { font-size: 15px; font-weight: 600; margin: 0 0 8px 0; }
  .card button {
    width: 100%; padding: 8px 12px; border-radius: 8px; border: none;
    background: var(--accent); color: var(--accent-text);
    font-size: 14px; cursor: pointer;
  }
  .card button:disabled {
    background: var(--qty-bg); color: var(--muted); cursor: not-allowed;
  }
  .floating {
    position: fixed; bottom: 20px; right: 20px;
    padding: 12px 20px; border-radius: 30px; border: none;
    background: var(--accent); color: var(--accent-text);
    font-size: 15px; font-weight: 600;
    box-shadow: 0 4px 16px rgba(0,0,0,0.25); cursor: pointer; z-index: 50;
  }
  .overlay {
    position: fixed; inset: 0; background: var(--overlay);
    display: none; align-items: flex-end; z-index: 100;
  }
  .overlay.open { display: flex; }
  .cart {
    width: 100%; max-height: 85vh; overflow-y: auto;
    background: var(--bg); border-top-left-radius: 20px;
    border-top-right-radius: 20px; padding: 20px;
  }
  .cart h2 { margin: 0 0 12px 0; font-size: 20px; }
  .cart .empty { color: var(--muted); text-align: center; padding: 20px 0; }
  .item {
    padding: 10px; border-radius: 10px;
    background: var(--card-bg); margin-bottom: 8px;
  }
  .item .row1 {
    display: flex; justify-content: space-between; align-items: flex-start;
    gap: 8px;
  }
  .item .name { font-size: 14px; font-weight: 600; }
  .item .line { font-size: 12px; color: var(--muted); margin-top: 4px; }
  .item .qty-controls {
    display: flex; align-items: center; gap: 6px; margin-top: 8px;
  }
  .item .qty-controls button {
    width: 26px; height: 26px; border-radius: 6px; border: none;
    background: var(--qty-bg); color: var(--text);
    font-size: 15px; cursor: pointer;
  }
  .item .qty-controls .val {
    min-width: 24px; text-align: center; font-size: 14px; font-weight: 600;
  }
  .item .remove {
    width: 26px; height: 26px; border-radius: 6px; border: none;
    background: var(--remove-bg); color: var(--remove-text);
    cursor: pointer; flex-shrink: 0;
  }
  .totals {
    margin-top: 16px; padding-top: 12px;
    border-top: 1px solid var(--divider); font-size: 14px;
  }
  .totals .row {
    display: flex; justify-content: space-between; margin-bottom: 6px;
  }
  .totals .row.commission { color: var(--muted); font-size: 13px; }
  .totals .row.final {
    font-size: 17px; font-weight: 700; margin-top: 10px;
    padding-top: 10px; border-top: 1px solid var(--divider);
  }
  .order {
    width: 100%; margin-top: 12px; padding: 14px 0;
    border-radius: 12px; border: none;
    background: var(--accent); color: var(--accent-text);
    font-size: 16px; font-weight: 600; cursor: pointer;
  }
  .close {
    width: 100%; margin-top: 8px; padding: 10px 0;
    border-radius: 12px; border: none; background: transparent;
    color: var(--muted); font-size: 14px; cursor: pointer;
  }
  .checkout h2 { margin: 0 0 4px 0; font-size: 20px; }
  .checkout .subtitle {
    font-size: 13px; color: var(--muted); margin: 0 0 16px 0;
  }
  .step {
    display: flex; gap: 10px;
    padding: 12px; border-radius: 10px;
    background: var(--card-bg); margin-bottom: 8px;
  }
  .step-num {
    flex-shrink: 0;
    width: 26px; height: 26px; border-radius: 50%;
    background: var(--accent); color: var(--accent-text);
    font-size: 14px; font-weight: 700;
    display: flex; align-items: center; justify-content: center;
  }
  .step-text {
    font-size: 13px; line-height: 1.45;
  }
  .step-text .link {
    color: var(--accent); text-decoration: none;
    font-weight: 600;
  }
  .step-text .amount {
    color: var(--green); font-weight: 700;
  }
  .final-note {
    margin-top: 14px; margin-bottom: 6px;
    text-align: center; font-size: 14px; font-weight: 600;
    color: var(--green);
  }
  .checkout .close {
    margin-top: 10px;
  }
</style>
</head>
<body class="dark">

<div class="theme-toggle" onclick="toggleTheme()">
  <div class="knob" id="themeKnob">🌙</div>
</div>

<h1 class="shop-title">Krayv Shop</h1>

<!-- Вкладки -->
<div class="tabs">
  <button class="tab active" onclick="switchTab('eng', this)">🔧 Инженерия</button>
  <button class="tab" onclick="switchTab('gifts', this)">🎁 Подарки</button>
</div>

<!-- Вкладка: Инженерия -->
<div class="tab-content active" id="tab-eng">
  <div class="grid" id="grid-eng"></div>
</div>

<!-- Вкладка: Подарки -->
<div class="tab-content" id="tab-gifts">
  <div class="grid" id="grid-gifts"></div>
</div>

<button class="floating" onclick="openCart()">
  🛒 Корзина <span id="cartCount"></span>
</button>

<!-- Корзина -->
<div class="overlay" id="overlay" onclick="closeCart(event)">
  <div class="cart" onclick="event.stopPropagation()">
    <div id="cartView">
      <h2>Корзина</h2>
      <div id="cartContent"></div>
    </div>

    <div id="checkoutView" class="checkout" style="display:none;">
      <h2>Оформление заказа</h2>
      <p class="subtitle">Следуй пунктам ниже</p>

      <div class="step">
        <div class="step-num">1</div>
        <div class="step-text">
          Убедитесь, что на вашем балансе достаточно звёзд
        </div>
      </div>

      <div class="step">
        <div class="step-num">2</div>
        <div class="step-text">
          Напишите в личку <span class="link">@krayverov</span>
        </div>
      </div>

      <div class="step">
        <div class="step-num">3</div>
        <div class="step-text">
          Отправьте звёзды подарками на сумму в корзине
          (<span class="amount" id="checkoutAmount">0</span> ⭐)
          и отметьте под 1 из подарков то, что вы купили.
          <br>Пример: колечко и ракету с подписью «за деф»
        </div>
      </div>

      <div class="step">
        <div class="step-num">4</div>
        <div class="step-text">
          Ожидайте проверки и выдачи заказа вплоть до 4 часов.
          Если мы опоздаем — вернём <b>10%</b> от заказа
          на все товары, кроме NFT.
        </div>
      </div>

      <div class="final-note">Удачных покупок 🛍️</div>

      <button class="close" onclick="backToCart()">← Назад в корзину</button>
    </div>
  </div>
</div>

<script>
  const products = [
    // Инженерия
    {
      id: 1, section: "eng",
      name: "софт sessionspam", price: 50,
      description: "спам софт тг входы",
      image: "https://i.ibb.co/pvzsB1FL/CYalvo-Egq-Vn1-VCg8x-B0-NU917s-hc4-ABoy-VPdb-B07x-G7-Emih-Or-C3w-INl-CXj-Yx-Wiyf-Exy-Bui-Katy-Vi-Vyf4-JFx.jpg",
      noCommission: true, allowMultiple: false
    },
    {
      id: 2, section: "eng",
      name: "Деф", price: 150,
      description: "защита от krayverov",
      image: "https://i.ibb.co/1tSVqcPq/Rz9qwz6-TROMzj-GQ0-Qe-AGTCjdo3y4-KJe-Im-Hkz-Db-Wqt-E8hig-q-Chhb77-Okx-NDdfv-ZXugl-Bmn-SPW0-NNyi-KYYGRVOv.jpg",
      noCommission: true, allowMultiple: false
    },
    {
      id: 3, section: "eng",
      name: "обучение", price: 150,
      description: "обучение от Krayverov",
      image: "https://i.ibb.co/1tSVqcPq/Rz9qwz6-TROMzj-GQ0-Qe-AGTCjdo3y4-KJe-Im-Hkz-Db-Wqt-E8hig-q-Chhb77-Okx-NDdfv-ZXugl-Bmn-SPW0-NNyi-KYYGRVOv.jpg",
      noCommission: true, allowMultiple: false
    },
    // Подарки
    {
      id: 4, section: "gifts",
      name: "мишка от Krayverov", price: 25,
      description: "мишка с росписью",
      image: "https://i.ibb.co/Pz0H462D/OTEnx61k-1932-l-Pq-Bzb-XT0acqxlc-K9f-FXCMf-Dks-Wu-M3s-II63-I3-Zlh-CLb-VRF9-Ge-XNsj3lc-N0-IMqn-UR-Jj6-P-k.jpg",
      noCommission: true, allowMultiple: true
    },
    {
      id: 5, section: "gifts",
      name: "рандом NFT", price: 600,
      description: "рандомное нфт выше или ниже своей цены",
      image: "https://i.ibb.co/Gvz3JYLB/50y-CDLtp-SN-f2-Lwl0-Sa2roya8n-RUYcie6-p7-BKlp-Qdo4g-JQMMOp-QKQ1jn-WHt2s-Seu-Um0sy-Rm-ZNV0chtj8x-J-gg.jpg",
      noCommission: false, allowMultiple: true
    },
    {
      id: 6, section: "gifts",
      name: "рандом BLACK NFT", price: 3500,
      description: "рандом нфт выше или ниже своей цены на блэк фоне",
      image: "https://i.ibb.co/7tNrN4Kt/Lg-Kj-XAj-Ea-Bpprqqyrxq1x8k-PE-q1-U9ghy0b7utxnald3a-KSPv-Iof5-L4-BKeirm5-Z27-Bv6-L-lw1ze61ri-QAKBzp-RD.jpg",
      noCommission: false, allowMultiple: true
    },
    {
      id: 7, section: "gifts",
      name: "бот по дешёвой аренде нфт", price: 15,
      description: "2 звезды за 3 дня нфт",
      image: "https://i.ibb.co/bMWjbZLY/GMSBiqf-SCob-Aq1ejk-JEy-AXke8-K4n-Tpy-Wo-Zv-W3zh-F30-Edh8plgf7-Zw-MDo-Ks-Tx-LDX8d-Z3-Nw-Cu7j-Gr-IFPx-Kr.jpg",
      noCommission: true, allowMultiple: false
    }
  ];

  let cart = [];
  const tg = window.Telegram?.WebApp;
  if (tg) { tg.ready(); tg.expand(); }

  function switchTab(section, btn) {
    document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));
    document.querySelectorAll(".tab-content").forEach(t => t.classList.remove("active"));
    btn.classList.add("active");
    document.getElementById("tab-" + section).classList.add("active");
  }

  function toggleTheme() {
    document.body.classList.toggle("dark");
    document.getElementById("themeKnob").textContent =
      document.body.classList.contains("dark") ? "🌙" : "☀️";
  }

  function getItem(id) {
    return cart.find(i => i.product.id === id);
  }

  function renderSection(sectionId, containerId) {
    const items = products.filter(p => p.section === sectionId);
    document.getElementById(containerId).innerHTML = items.map(p => {
      const inCart = getItem(p.id);
      const disabled = inCart && !p.allowMultiple;
      let btnText = "В корзину";
      if (inCart && !p.allowMultiple) btnText = "Уже в корзине";
      if (inCart && p.allowMultiple) btnText = "Ещё +1";

      return `
      <div class="card">
        <div class="card-img-wrap">
          <img src="${p.image}" alt="${p.name}">
        </div>
        <h3>${p.name}</h3>
        <p class="desc">${p.description}</p>
        <p class="price">${p.price} ⭐</p>
        <button onclick="addToCart(${p.id})" ${disabled ? "disabled" : ""}>
          ${btnText}
        </button>
      </div>
    `}).join("");
  }

  function renderGrid() {
    renderSection("eng", "grid-eng");
    renderSection("gifts", "grid-gifts");
  }

  function addToCart(id) {
    const product = products.find(p => p.id === id);
    const existing = getItem(id);
    if (existing) {
      if (!product.allowMultiple) return;
      existing.qty += 1;
    } else {
      cart.push({ product, qty: 1 });
    }
    renderGrid();
    renderCart();
  }

  function increaseQty(id) {
    const item = getItem(id);
    if (!item || !item.product.allowMultiple) return;
    item.qty += 1;
    renderGrid();
    renderCart();
  }

  function decreaseQty(id) {
    const item = getItem(id);
    if (!item) return;
    item.qty -= 1;
    if (item.qty <= 0) cart = cart.filter(i => i.product.id !== id);
    renderGrid();
    renderCart();
  }

  function removeFromCart(id) {
    cart = cart.filter(i => i.product.id !== id);
    renderGrid();
    renderCart();
  }

  function baseSum() {
    return cart.reduce((s, i) => s + i.product.price * i.qty, 0);
  }
  function commissionSum() {
    return cart.reduce((s, i) => {
      if (i.product.noCommission) return s;
      return s + i.product.price * i.qty * 0.2;
    }, 0);
  }
  function totalSum() { return baseSum() + commissionSum(); }
  function totalCount() { return cart.reduce((s, i) => s + i.qty, 0); }

  function renderCart() {
    document.getElementById("cartCount").textContent =
      totalCount() > 0 ? "(" + totalCount() + ")" : "";
    const c = document.getElementById("cartContent");
    if (cart.length === 0) {
      c.innerHTML = '<p class="empty">Пока пусто</p><button class="close" onclick="closeCart()">Закрыть</button>';
      return;
    }

    let itemsHtml = cart.map(i => {
      const lineSum = i.product.price * i.qty;
      const comm = i.product.noCommission ? 0 : lineSum * 0.2;
      const commText = i.product.noCommission
        ? "Без комиссии"
        : "+ " + comm.toFixed(0) + " ⭐ комиссия";

      const qtyControls = i.product.allowMultiple ? `
        <div class="qty-controls">
          <button onclick="decreaseQty(${i.product.id})">−</button>
          <span class="val">${i.qty}</span>
          <button onclick="increaseQty(${i.product.id})">+</button>
        </div>
      ` : "";

      return `
      <div class="item">
        <div class="row1">
          <div style="flex:1">
            <div class="name">${i.product.name}</div>
            <div class="line">${i.product.price} ⭐ × ${i.qty} = ${lineSum} ⭐</div>
            <div class="line">${commText}</div>
            ${qtyControls}
          </div>
          <button class="remove" onclick="removeFromCart(${i.product.id})">✕</button>
        </div>
      </div>`;
    }).join("");

    const base = baseSum();
    const comm = commissionSum();
    const total = base + comm;

    itemsHtml += `
      <div class="totals">
        <div class="row"><span>Товары:</span><span>${base} ⭐</span></div>
        ${comm > 0 ? `<div class="row commission"><span>Комиссия Telegram (+20%):</span><span>+${comm.toFixed(0)} ⭐</span></div>` : ""}
        <div class="row final"><span>Итого:</span><span>${total.toFixed(0)} ⭐</span></div>
      </div>
      <button class="order" onclick="showCheckout()">Оформить заказ</button>
      <button class="close" onclick="closeCart()">Закрыть</button>
    `;
    c.innerHTML = itemsHtml;
  }

  function openCart() {
    renderCart();
    showCartView();
    document.getElementById("overlay").classList.add("open");
  }

  function closeCart(e) {
    if (e && e.target.id !== "overlay" && e.target.className !== "close") return;
    document.getElementById("overlay").classList.remove("open");
  }

  function showCartView() {
    document.getElementById("cartView").style.display = "block";
    document.getElementById("checkoutView").style.display = "none";
  }

  function showCheckout() {
    if (cart.length === 0) return;
    document.getElementById("checkoutAmount").textContent = totalSum().toFixed(0);
    document.getElementById("cartView").style.display = "none";
    document.getElementById("checkoutView").style.display = "block";
  }

  function backToCart() {
    showCartView();
    renderCart();
  }

  renderGrid();
  renderCart();
</script>

</body>
</html>
