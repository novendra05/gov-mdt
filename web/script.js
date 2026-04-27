let currentCitizenId = null;
let currentUser = null;
const BOSS_GRADE = 3;

window.addEventListener('message', function(event) {
    let data = event.data;
    console.log('NUI Message Received:', data.action);

    if (data.action === 'open') {
        try {
            console.log('Opening Government MDT...');
            const app = document.getElementById('app');
            if (app) {
                app.style.display = 'flex';
                app.classList.remove('hidden');
            }
            
            currentUser = data.user;
            const nameEl = document.getElementById('user-name');
            const jobEl = document.getElementById('user-job');
            if (nameEl) nameEl.innerText = currentUser.name || 'Unknown';
            if (jobEl) jobEl.innerText = currentUser.job || 'Government';

            // TEMPORARY: Allow all ranks to see all menus for verification
            const navLinks = document.querySelectorAll('.nav-links button[data-page]');
            navLinks.forEach(btn => {
                btn.style.display = 'flex';
                btn.onclick = function() {
                    navigateTo(this.getAttribute('data-page'), this);
                };
            });
            
            const btnAnnounce = document.getElementById('btn-add-announce');
            const btnDoc = document.getElementById('btn-add-doc');
            if (btnAnnounce) btnAnnounce.style.display = 'flex';
            if (btnDoc) btnDoc.style.display = 'flex';

            // Reset to dashboard
            navigateTo('dashboard', document.querySelector('[data-page="dashboard"]'));

            if (data.dashboard) {
                updateDashboard(data.dashboard);
            }
        } catch (err) {
            console.error('Error during MDT open:', err);
        }
    } else if (data.action === 'close') {
        document.getElementById('app').classList.add('hidden');
    } else if (data.action === 'updateSearchResults') {
        renderSearchResults(data.results);
    } else if (data.action === 'updateCitizenProfile') {
        renderProfile(data.profile);
    } else if (data.action === 'renderMarketItems') {
        renderMarketItems(data);
    } else if (data.action === 'renderSalesLogs') {
        renderSalesLogs(data.logs);
    } else if (data.action === 'updateAnnouncements') {
        renderAnnouncements(data.data);
    } else if (data.action === 'viewDocument') {
        openViewDoc(data.doc);
    }
});

function notify(title, message, type = 'info') {
    const container = document.getElementById('notification-container');
    const id = Date.now();
    
    const borderColor = type === 'success' ? 'border-green-500/50' : (type === 'error' ? 'border-red-500/50' : 'border-blue-500/50');
    const icon = type === 'success' ? 'fa-check-circle' : (type === 'error' ? 'fa-exclamation-circle' : 'fa-info-circle');
    const iconColor = type === 'success' ? 'text-green-500' : (type === 'error' ? 'text-red-500' : 'text-blue-500');

    const toast = document.createElement('div');
    toast.className = `bg-gray-900 border ${borderColor} p-4 rounded-2xl shadow-2xl min-w-[300px] animate-fade-in pointer-events-auto transition-all duration-500`;
    toast.id = `toast-${id}`;
    toast.innerHTML = `
        <div class="flex items-center gap-4">
            <div class="h-10 w-10 rounded-xl flex items-center justify-center bg-gray-950 border border-gray-800">
                <i class="fas ${icon} ${iconColor} text-lg"></i>
            </div>
            <div>
                <h4 class="text-[10px] font-black uppercase tracking-widest text-white leading-none mb-1">${title}</h4>
                <p class="text-[11px] text-gray-400 font-medium">${message}</p>
            </div>
        </div>
    `;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(50px)';
        setTimeout(() => toast.remove(), 500);
    }, 4000);
}

function openConfirmModal(message, onConfirm) {
    document.getElementById('modal-confirm').classList.remove('hidden');
    document.getElementById('confirm-message').innerText = message;
    document.getElementById('confirm-button').onclick = () => {
        onConfirm();
        closeConfirmModal();
    };
}

function closeConfirmModal() {
    document.getElementById('modal-confirm').classList.add('hidden');
}

// Close MDT on ESC
document.onkeydown = function (data) {
    if (data.which == 27) { // Escape key
        closeMDT();
    }
};


function loadMarketItems() {
    fetch(`https://${GetParentResourceName()}/getMarketItems`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function loadSalesLogs() {
    console.log('Loading Sales Logs...');
    const filterEl = document.getElementById('filter-sales-date');
    const filterDate = filterEl ? filterEl.value : '';
    
    fetch(`https://${GetParentResourceName()}/getSalesLogs`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ date: filterDate })
    }).then(resp => resp.json()).then(data => {
        if (data) {
            renderSalesLogs(data);
        }
    }).catch(err => console.error('Error loading sales logs:', err));
}

function resetSalesFilter() {
    document.getElementById('filter-sales-date').value = '';
    loadSalesLogs();
}

function removeMarketItem(id) {
    openConfirmModal("Are you sure you want to remove this item from the market?", () => {
        fetch(`https://${GetParentResourceName()}/removeMarketItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
        }).then(() => {
            notify("Removed", "Item has been deleted.", "error");
            loadMarketItems();
        });
    });
}

function closeMDT() {
    console.log('Closing MDT UI...');
    const app = document.getElementById('app');
    if (app) {
        app.style.display = 'none';
        app.classList.add('hidden');
    }
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// Navigation
function navigateTo(page, element) {
    try {
        console.log('Navigating to:', page);
        // Handle Warehouse immediately (opens stash)
        if (page === 'warehouse') {
            fetch(`https://${GetParentResourceName()}/openWarehouse`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
            closeMDT();
            return;
        }

        // Standard Page Switching
        const targetPage = document.getElementById('page-' + page);
        if (!targetPage) {
            console.warn('Target page not found:', 'page-' + page);
            return;
        }

        // Update Sidebar UI
        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.classList.remove('active', 'bg-gray-800', 'text-white');
            btn.classList.add('text-gray-300');
        });
        
        if (element) {
            element.classList.add('active', 'bg-gray-800', 'text-white');
            element.classList.remove('text-gray-300');
        }
        
        // Load page specific data
        if (page === 'citizens') {
            const results = document.getElementById('citizen-results');
            const profile = document.getElementById('citizen-profile');
            if (results) results.classList.remove('hidden');
            if (profile) profile.classList.add('hidden');
        }

        if (page === 'market_settings') loadMarketItems();
        if (page === 'sales') loadSalesLogs();
        if (page === 'department') loadEmployees();
        if (page === 'announcements') loadAnnouncements();
        if (page === 'documents') loadDocuments();

        // Toggle page visibility
        console.log('Hiding all pages...');
        const allPages = document.querySelectorAll('.page');
        allPages.forEach(p => {
            p.style.display = 'none';
            p.classList.remove('active');
            console.log('Hid page:', p.id);
        });
        
        targetPage.style.display = 'block';
        targetPage.classList.add('active');
        console.log('Showing page:', targetPage.id);
    } catch (err) {
        console.error('Error in navigateTo:', err);
    }
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    console.log('MDT UI Initialized');
    document.querySelectorAll('.nav-btn[data-page]').forEach(btn => {
        btn.addEventListener('click', function() {
            const page = this.getAttribute('data-page');
            navigateTo(page, this);
        });
    });
});

function updateDashboard(data) {
    try {
        if (!data) return;
        console.log('Updating Dashboard Stats...');
        
        const elements = {
            'stat-total-citizens': data.totalCitizens || 0,
            'stat-total-revenue': '$' + (data.totalRevenue || 0).toLocaleString(),
            'stat-top-item': data.topItem || 'None',
            'stat-warehouse-health': (data.warehouseHealth || 0) + '%',
            'current-date': new Date().toLocaleDateString('en-GB')
        };

        for (const [id, value] of Object.entries(elements)) {
            const el = document.getElementById(id);
            if (el) el.innerText = value;
        }

        // Handle Latest Announcement
        const announceContainer = document.getElementById('latest-announcement-container');
        const announceTitle = document.getElementById('dash-announce-title');
        const announceMsg = document.getElementById('dash-announce-msg');
        const announceAuthor = document.getElementById('dash-announce-author');
        const announceDate = document.getElementById('dash-announce-date');

        if (data.latestAnnouncement && announceTitle) {
            if (announceContainer) announceContainer.classList.remove('hidden');
            announceTitle.innerText = data.latestAnnouncement.title;
            if (announceMsg) announceMsg.innerText = data.latestAnnouncement.message;
            if (announceAuthor) announceAuthor.innerText = 'By: ' + data.latestAnnouncement.author;
            if (announceDate) announceDate.innerText = new Date(data.latestAnnouncement.timestamp).toLocaleDateString('en-GB');
        } else if (announceContainer) {
            announceContainer.classList.add('hidden');
        }

        const tbody = document.querySelector('#recent-sales-table tbody');
        if (tbody) {
            tbody.innerHTML = '';
            if (data.recentSales && data.recentSales.length > 0) {
                data.recentSales.forEach(log => {
                    const isPurchase = log.price < 0;
                    const priceText = isPurchase ? `+$${Math.abs(log.price)}` : `-$${log.price}`;
                    const priceColor = isPurchase ? 'text-green-400' : 'text-red-400';
                    
                    const row = `
                        <tr class="hover:bg-gray-800/30 transition">
                            <td class="px-6 py-4 font-semibold text-gray-200">${log.name}</td>
                            <td class="px-6 py-4 text-gray-400">${log.item}</td>
                            <td class="px-6 py-4 font-mono">${log.amount}x</td>
                            <td class="px-6 py-4 font-bold ${priceColor}">${priceText}</td>
                        </tr>
                    `;
                    tbody.innerHTML += row;
                });
            } else {
                tbody.innerHTML = '<tr><td colspan="4" class="px-6 py-8 text-center text-gray-600">No recent activity</td></tr>';
            }
        }
    } catch (e) {
        console.error('Error in updateDashboard:', e);
    }
}

function searchCitizens() {
    const query = document.getElementById('citizen-search-input').value;
    if (query.trim() === '') return;
    
    fetch(`https://${GetParentResourceName()}/searchCitizens`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: query })
    });
}

function renderSearchResults(results) {
    const list = document.getElementById('citizen-results');
    list.innerHTML = '';
    
    if (results.length === 0) {
        list.innerHTML = '<div class="col-span-2 text-center py-10 text-gray-500 italic">No citizens found.</div>';
        return;
    }

    results.forEach(res => {
        const div = document.createElement('div');
        div.className = 'bg-gray-900/50 border border-gray-700 p-4 rounded-xl cursor-pointer hover:border-blue-500 hover:bg-gray-800/50 transition flex justify-between items-center';
        div.innerHTML = `
            <div>
                <span class="block font-bold text-white">${res.fullname}</span>
                <div class="flex gap-4 mt-1">
                    <span class="text-[10px] text-blue-400 font-bold tracking-widest uppercase">CID: ${res.citizenid}</span>
                    <span class="text-[10px] text-gray-500 font-bold tracking-widest uppercase">DOB: ${res.dob}</span>
                </div>
            </div>
            <i class="fas fa-chevron-right text-gray-700"></i>
        `;
        div.onclick = () => {
            fetch(`https://${GetParentResourceName()}/getCitizenDetails`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ citizenid: res.citizenid })
            });
        };
        list.appendChild(div);
    });
}

function renderProfile(data) {
    document.getElementById('citizen-results').classList.add('hidden');
    document.getElementById('citizen-profile').classList.remove('hidden');
    
    currentCitizenId = data.citizenid;
    document.getElementById('profile-name').innerText = data.firstname + ' ' + data.lastname;
    document.getElementById('profile-cid').innerText = 'CID: ' + data.citizenid;
    document.getElementById('profile-phone').innerText = data.phone || 'N/A';
    document.getElementById('profile-dob').innerText = data.birthdate || 'N/A';
    document.getElementById('profile-nationality').innerText = data.nationality || 'N/A';
    document.getElementById('profile-job').innerText = data.job || 'Unemployed';
    
    // Render Licenses
    const licenses = data.licences || {};
    const renderLic = (type, id) => {
        const has = licenses[type];
        const color = has ? 'text-green-500 bg-green-500/10 border-green-500/20' : 'text-red-500 bg-red-500/10 border-red-500/20';
        const label = has ? 'Active' : 'None';
        const btnClass = currentUser.grade_level >= BOSS_GRADE ? 'cursor-pointer hover:bg-gray-800' : '';
        
        document.getElementById(id).innerHTML = `
            <div onclick="toggleLicense('${data.citizenid}', '${type}', ${!has})" class="px-3 py-1 rounded-lg border text-[10px] font-black uppercase transition ${color} ${btnClass}">
                ${label}
            </div>
        `;
    };

    renderLic('driver', 'license-driver');
    renderLic('weapon', 'license-weapon');
    renderLic('business', 'license-business');


    // Render Family Members
    const familyList = document.getElementById('family-list');
    familyList.innerHTML = '';
    
    if (data.family && data.family.length > 0) {
        data.family.forEach(member => {
            const div = document.createElement('div');
            div.className = 'bg-gray-900 border border-gray-700/50 p-3 rounded-xl flex justify-between items-center shadow-sm';
            div.innerHTML = `
                <span class="text-sm font-semibold text-gray-200">${member.name}</span>
                <span class="text-[10px] text-blue-400 font-bold tracking-widest uppercase">${member.citizenid}</span>
            `;
            familyList.appendChild(div);
        });
    } else {
        familyList.innerHTML = '<div class="col-span-2 text-gray-600 text-xs italic py-4 bg-gray-900/30 rounded-xl text-center border border-dashed border-gray-800">No other family members linked to this household.</div>';
    }
}

function backToSearch() {
    document.getElementById('citizen-results').classList.remove('hidden');
    document.getElementById('citizen-profile').classList.add('hidden');
}

function saveKK() {
    const kk = document.getElementById('profile-kk').value;
    fetch(`https://${GetParentResourceName()}/saveKK`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid: currentCitizenId, kk: kk })
    });
}

let currentMarketData = { items: [], categories: [] };

function openAddItemModal(editData = null) {
    document.getElementById('modal-container').classList.remove('hidden');
    const title = document.querySelector('#modal-container h3');
    const submitBtn = document.querySelector('#modal-container button[onclick="submitNewItem()"]');

    if (editData) {
        title.innerText = "Edit Market Item";
        submitBtn.innerText = "Save Changes";
        document.getElementById('input-item-name').value = editData.item;
        document.getElementById('input-item-name').readOnly = true;
        document.getElementById('input-item-label').value = editData.label;
        document.getElementById('input-item-price').value = editData.price;
        document.getElementById('input-item-sell-price').value = editData.sell_price || 0;
        document.getElementById('input-item-stock').value = editData.max_stock;
        document.getElementById('input-item-category').value = editData.category;
    } else {
        title.innerText = "Add Market Item";
        submitBtn.innerText = "Confirm Add";
        document.getElementById('input-item-name').value = '';
        document.getElementById('input-item-name').readOnly = false;
        document.getElementById('input-item-label').value = '';
        document.getElementById('input-item-price').value = '';
        document.getElementById('input-item-sell-price').value = '';
        document.getElementById('input-item-stock').value = '';
        document.getElementById('input-item-category').value = '';
    }
}

function editMarketItem(id) {
    const item = currentMarketData.items.find(i => i.id === id);
    if (item) {
        openAddItemModal(item);
    }
}

function closeModal() {
    document.getElementById('modal-container').classList.add('hidden');
}

function submitNewItem() {
    const item = document.getElementById('input-item-name').value;
    const label = document.getElementById('input-item-label').value;
    const price = document.getElementById('input-item-price').value;
    const sellPrice = document.getElementById('input-item-sell-price').value;
    const stock = document.getElementById('input-item-stock').value;
    const category = document.getElementById('input-item-category').value;

    if (!item || !label || !price || !category || !stock || !sellPrice) return;

    fetch(`https://${GetParentResourceName()}/updateMarketItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
            item, label, 
            price: parseInt(price), 
            sell_price: parseInt(sellPrice),
            category, 
            max_stock: parseInt(stock) 
        })
    }).then(() => {
        closeModal();
        notify("Success", "Item updated in market.", "success");
        loadMarketItems();
    });
}

function openAddCategoryModal() {
    document.getElementById('modal-category').classList.remove('hidden');
    document.getElementById('input-cat-name').value = '';
    document.getElementById('input-cat-label').value = '';
}

function closeCategoryModal() {
    document.getElementById('modal-category').classList.add('hidden');
}

function submitNewCategory() {
    const name = document.getElementById('input-cat-name').value;
    const label = document.getElementById('input-cat-label').value;

    if (!name || !label) return;

    fetch(`https://${GetParentResourceName()}/addCategory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, label })
    }).then(() => {
        closeCategoryModal();
        notify("Success", "New category created.", "success");
        loadMarketItems();
    });
}

function removeCategory(id) {
    openConfirmModal("Removing a category will NOT delete items but may break their warehouse link. Continue?", () => {
        fetch(`https://${GetParentResourceName()}/removeCategory`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
        }).then(() => {
            notify("Removed", "Category has been deleted.", "error");
            loadMarketItems();
        });
    });
}

function renderMarketItems(data) {
    currentMarketData = data;
    const items = data.items;
    const categories = data.categories;
    const isBoss = currentUser.grade_level >= BOSS_GRADE;

    // Render Categories Tags
    const catList = document.getElementById('categories-list');
    if (catList) {
        catList.innerHTML = '';
        categories.forEach(cat => {
            const div = `
                <div class="bg-gray-800/50 border border-gray-700 p-3 rounded-xl flex justify-between items-center shadow-sm">
                    <div class="flex flex-col">
                        <span class="text-xs font-bold text-white">${cat.label}</span>
                        <span class="text-[9px] text-gray-500 font-mono">gov_stash_${cat.name}</span>
                    </div>
                    ${isBoss ? `<button onclick="removeCategory(${cat.id})" class="text-gray-600 hover:text-red-500 transition">
                        <i class="fas fa-times"></i>
                    </button>` : ''}
                </div>
            `;
            catList.innerHTML += div;
        });
    }

    // Update Dropdown in Modal
    const select = document.getElementById('input-item-category');
    if (select) {
        select.innerHTML = '<option value="" disabled selected>Select Category</option>';
        categories.forEach(cat => {
            select.innerHTML += `<option value="${cat.name}">${cat.label}</option>`;
        });
    }

    // Render Items Table
    const tbody = document.querySelector('#market-items-table tbody');
    if (!tbody) return;
    tbody.innerHTML = '';
    items.forEach(item => {
        const stockPercent = Math.min((item.current_stock / item.max_stock) * 100, 100);
        const stockColor = stockPercent >= 100 ? 'bg-red-500' : (stockPercent >= 80 ? 'bg-orange-500' : 'bg-blue-500');
        
        const row = `
            <tr class="hover:bg-gray-800/30 transition">
                <td class="px-6 py-4">
                    <span class="bg-blue-600/10 text-blue-400 border border-blue-400/20 px-2 py-1 rounded text-[10px] font-black uppercase tracking-widest">${item.category}</span>
                </td>
                <td class="px-6 py-4 font-semibold text-gray-200">${item.label}</td>
                <td class="px-6 py-4 text-gray-500 font-mono text-[11px]">${item.item}</td>
                <td class="px-6 py-4 text-green-400 font-bold">$${item.price}</td>
                <td class="px-6 py-4 text-orange-400 font-bold">$${item.sell_price || 0}</td>
                <td class="px-6 py-4">
                    <div class="w-32">
                        <div class="flex justify-between text-[9px] mb-1 font-bold uppercase tracking-widest">
                            <span class="${stockPercent >= 100 ? 'text-red-400' : 'text-gray-400'}">${item.current_stock} / ${item.max_stock}</span>
                            <span class="text-gray-600">${Math.round(stockPercent)}%</span>
                        </div>
                        <div class="w-full h-1 bg-gray-800 rounded-full overflow-hidden">
                            <div class="h-full ${stockColor} transition-all duration-500" style="width: ${stockPercent}%"></div>
                        </div>
                    </div>
                </td>
                <td class="px-6 py-4 text-right flex gap-1 justify-end">
                    ${isBoss ? `
                        <button onclick="editMarketItem(${item.id})" class="text-blue-400 hover:text-blue-300 transition p-2">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button onclick="removeMarketItem(${item.id})" class="text-red-500 hover:text-red-400 transition p-2">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                    ` : '<span class="text-gray-600 text-[10px]">Read Only</span>'}
                </td>
            </tr>
        `;
        tbody.innerHTML += row;
    });
}

function renderSalesLogs(logs) {
    const tbody = document.querySelector('#full-sales-table tbody');
    if (!tbody) return;
    tbody.innerHTML = '';

    if (!logs || logs.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="px-6 py-8 text-center text-gray-600">No transactions found for this date.</td></tr>';
        return;
    }

    logs.forEach(log => {
        const date = new Date(log.timestamp).toLocaleString('en-GB', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' });
        const row = `
            <tr class="hover:bg-gray-800/30 transition">
                <td class="px-6 py-4 text-gray-500 text-[11px] font-mono">${date}</td>
                <td class="px-6 py-4 font-bold text-white">${log.name}</td>
                <td class="px-6 py-4 text-blue-400 font-mono text-xs">${log.citizenid}</td>
                <td class="px-6 py-4 text-gray-400">${log.item}</td>
                <td class="px-6 py-4 font-mono">${log.amount}x</td>
                <td class="px-6 py-4 text-green-400 font-bold">$${log.price.toLocaleString()}</td>
            </tr>
        `;
        tbody.innerHTML += row;
    });
}

// License Management
function toggleLicense(citizenid, licenseType, state) {
    if (currentUser.grade_level < BOSS_GRADE) {
        notify('Permission Denied', 'Only high rank can manage licenses.', 'error');
        return;
    }

    openConfirmModal(`Are you sure you want to ${state ? 'GRANT' : 'REVOKE'} the ${licenseType} license?`, () => {
        fetch(`https://${GetParentResourceName()}/updateLicense`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ citizenid, licenseType, state })
        }).then(resp => resp.json()).then(data => {
            if (data.success) {
                notify('Success', data.message, 'success');
                // Refresh profile
                fetch(`https://${GetParentResourceName()}/getCitizenDetails`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ citizenid })
                });
            } else {
                notify('Error', data.message, 'error');
            }
        });
    });
}

// Announcements
function openAnnounceModal() {
    document.getElementById('modal-announce').classList.remove('hidden');
}

function closeAnnounceModal() {
    document.getElementById('modal-announce').classList.add('hidden');
}

function submitNewAnnouncement() {
    const title = document.getElementById('input-announce-title').value;
    const msg = document.getElementById('input-announce-msg').value;

    if (!title || !msg) return notify('Required', 'Please fill all fields', 'error');

    fetch(`https://${GetParentResourceName()}/addAnnouncement`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, message: msg })
    }).then(resp => resp.json()).then(success => {
        if (success) {
            notify('Posted', 'Announcement published successfully', 'success');
            closeAnnounceModal();
            loadAnnouncements();
        }
    });
}

function loadAnnouncements() {
    fetch(`https://${GetParentResourceName()}/getAnnouncements`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
        renderAnnouncements(data);
    });
}

function renderAnnouncements(data) {
    const list = document.getElementById('announcements-list');
    list.innerHTML = '';
    const isBoss = currentUser.grade_level >= BOSS_GRADE;

    data.forEach(item => {
        const div = `
            <div class="bg-gray-900/50 border border-gray-700 p-6 rounded-2xl relative group">
                <div class="flex justify-between items-start mb-2">
                    <h4 class="text-lg font-bold text-white">${item.title}</h4>
                    ${isBoss ? `<button onclick="deleteAnnouncement(${item.id})" class="text-gray-600 hover:text-red-500 transition"><i class="fas fa-trash"></i></button>` : ''}
                </div>
                <p class="text-gray-400 text-sm mb-4 leading-relaxed">${item.message}</p>
                <div class="flex items-center gap-4 text-[10px] font-bold text-gray-500 uppercase tracking-widest">
                    <span>By: ${item.author}</span>
                    <span>•</span>
                    <span>${new Date(item.timestamp).toLocaleString('en-GB')}</span>
                </div>
            </div>
        `;
        list.innerHTML += div;
    });
}

// Department Management
function loadEmployees() {
    fetch(`https://${GetParentResourceName()}/getEmployees`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
        renderEmployees(data);
    });
}

function renderEmployees(data) {
    const tbody = document.querySelector('#department-table tbody');
    tbody.innerHTML = '';

    data.sort((a, b) => b.grade - a.grade).forEach(emp => {
        const statusColor = emp.isOnline ? 'bg-green-500' : 'bg-gray-700';
        const row = `
            <tr class="hover:bg-gray-800/30 transition">
                <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                        <div class="h-2 w-2 rounded-full ${statusColor}"></div>
                        <div>
                            <p class="font-bold text-white">${emp.name}</p>
                            <p class="text-[10px] text-gray-500 uppercase font-mono">${emp.citizenid}</p>
                        </div>
                    </div>
                </td>
                <td class="px-6 py-4">
                    <span class="bg-blue-600/10 text-blue-400 px-3 py-1 rounded-lg border border-blue-500/20 text-[10px] font-bold uppercase tracking-widest">
                        ${emp.grade_name} (${emp.grade})
                    </span>
                </td>
                <td class="px-6 py-4 text-right flex gap-1 justify-end">
                    <button onclick="changeGrade('${emp.citizenid}', ${emp.grade + 1})" class="p-2 text-gray-500 hover:text-green-400 transition" title="Promote">
                        <i class="fas fa-arrow-up"></i>
                    </button>
                    <button onclick="changeGrade('${emp.citizenid}', ${emp.grade - 1})" class="p-2 text-gray-500 hover:text-orange-400 transition" title="Demote">
                        <i class="fas fa-arrow-down"></i>
                    </button>
                    <button onclick="fireEmployee('${emp.citizenid}')" class="p-2 text-gray-500 hover:text-red-500 transition" title="Fire">
                        <i class="fas fa-user-minus"></i>
                    </button>
                </td>
            </tr>
        `;
        tbody.innerHTML += row;
    });
}

function changeGrade(citizenid, newGrade) {
    if (newGrade < 0 || newGrade > 3) return notify('Limit', 'Grade must be between 0 and 3', 'error');
    
    fetch(`https://${GetParentResourceName()}/updateEmployeeGrade`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid, newGrade })
    }).then(resp => resp.json()).then(success => {
        if (success) {
            notify('Success', 'Employee rank updated', 'success');
            loadEmployees();
        }
    });
}

function fireEmployee(citizenid) {
    openConfirmModal('Are you sure you want to FIRE this employee?', () => {
        fetch(`https://${GetParentResourceName()}/fireEmployee`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ citizenid })
        }).then(resp => resp.json()).then(success => {
            if (success) {
                notify('Success', 'Employee has been fired', 'success');
                loadEmployees();
            }
        });
    });
}

function deleteAnnouncement(id) {
    openConfirmModal('Delete this announcement?', () => {
        fetch(`https://${GetParentResourceName()}/deleteAnnouncement`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
        }).then(resp => resp.json()).then(success => {
            if (success) {
                notify('Deleted', 'Announcement removed', 'success');
                loadAnnouncements();
            }
        });
    });
}
// Hire Management
function openHireModal() {
    document.getElementById('modal-hire').classList.remove('hidden');
    document.getElementById('input-hire-cid').focus();
    
    // Fetch nearby
    fetch(`https://${GetParentResourceName()}/getNearbyPlayers`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(players => {
        const list = document.getElementById('nearby-players-list');
        list.innerHTML = '';
        if (!players || players.length === 0) {
            list.innerHTML = '<p class="text-[10px] text-gray-600 italic">No one nearby...</p>';
            return;
        }

        players.forEach(p => {
            const div = document.createElement('div');
            div.className = 'flex items-center justify-between bg-gray-950 p-2 rounded-lg border border-gray-800 hover:border-green-500/50 cursor-pointer transition';
            div.onclick = () => selectNearbyPlayer(p.citizenid);
            div.innerHTML = `
                <div class="text-left">
                    <p class="text-xs font-bold text-white">${p.name}</p>
                    <p class="text-[9px] text-gray-500 font-mono">${p.citizenid}</p>
                </div>
                <i class="fas fa-plus text-green-500 text-[10px]"></i>
            `;
            list.appendChild(div);
        });
    });
}

function selectNearbyPlayer(cid) {
    document.getElementById('input-hire-cid').value = cid;
}

function closeHireModal() {
    document.getElementById('modal-hire').classList.add('hidden');
    document.getElementById('input-hire-cid').value = '';
}

function submitHire() {
    const cid = document.getElementById('input-hire-cid').value.trim();
    if (!cid) return notify('Required', 'Please enter a Citizen ID', 'error');

    fetch(`https://${GetParentResourceName()}/hireEmployee`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid: cid })
    }).then(resp => resp.json()).then(success => {
        if (success) {
            notify('Success', `Citizen ${cid} has been hired.`, 'success');
            closeHireModal();
            loadEmployees();
        } else {
            notify('Error', 'Citizen not found or already employed.', 'error');
        }
    });
}

function copyCID() {
    if (!currentCitizenId) return;
    copyToClipboard(currentCitizenId);
    notify('Copied', 'Citizen ID copied to clipboard', 'success');
}

function copyToClipboard(text) {
    const el = document.createElement('textarea');
    el.value = text;
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    document.body.removeChild(el);
}

// Legal Documents
function loadDocuments() {
    fetch(`https://${GetParentResourceName()}/getDocuments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
        renderDocuments(data);
    });
}

function renderDocuments(data) {
    const list = document.getElementById('documents-list');
    if (!list) return;
    list.innerHTML = '';
    
    // Safety check for user rank
    const isBoss = (currentUser && currentUser.grade_level >= BOSS_GRADE) || false;

    data.forEach(item => {
        const div = `
            <div class="bg-gray-900/50 border border-gray-700 p-6 rounded-2xl relative group">
                <div class="flex justify-between items-start mb-2">
                    <h4 class="text-lg font-bold text-white">${item.title}</h4>
                    <div class="flex gap-2">
                        <button onclick="showDocument(${item.id})" class="text-gray-400 hover:text-blue-400 transition" title="Show to Nearby Citizens">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button onclick="giveDocument(${item.id})" class="text-green-500 hover:text-green-300 transition" title="Give Physical Copy">
                            <i class="fas fa-file-signature"></i>
                        </button>
                        <button onclick="openEditDocModal(${item.id})" class="text-gray-500 hover:text-yellow-400 transition" title="Edit Document">
                            <i class="fas fa-edit"></i>
                        </button>
                        ${isBoss ? `<button onclick="deleteDocument(${item.id})" class="text-gray-600 hover:text-red-500 transition"><i class="fas fa-trash"></i></button>` : ''}
                    </div>
                </div>
                <p class="text-gray-400 text-[11px] mb-4 line-clamp-2">${item.content}</p>
                <div class="flex items-center gap-4 text-[9px] font-bold text-gray-500 uppercase tracking-widest">
                    <span>${item.author}</span>
                    <span>•</span>
                    <span>${new Date(item.timestamp).toLocaleDateString('en-GB')}</span>
                </div>
            </div>
        `;
        list.innerHTML += div;
    });
}

let editingDocId = null;

function openDocModal() {
    editingDocId = null;
    document.getElementById('modal-document').classList.remove('hidden');
    document.getElementById('modal-doc-title-text').innerText = 'New Legal Document';
}

function openEditDocModal(id) {
    editingDocId = id;
    
    // Find the doc data from the list or fetch it? 
    // Since we just loaded them, let's find it in the DOM or fetch it.
    // Fetching is safer.
    fetch(`https://${GetParentResourceName()}/getDocumentById`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id })
    }).then(resp => resp.json()).then(doc => {
        if (!doc) return;
        document.getElementById('modal-document').classList.remove('hidden');
        document.getElementById('modal-doc-title-text').innerText = 'Edit Legal Document';
        document.getElementById('input-doc-title').value = doc.title;
        document.getElementById('input-doc-content').value = doc.content;
    });
}

function closeDocModal() {
    document.getElementById('modal-document').classList.add('hidden');
    document.getElementById('input-doc-title').value = '';
    document.getElementById('input-doc-content').value = '';
    editingDocId = null;
}

function submitNewDocument() {
    const title = document.getElementById('input-doc-title').value;
    const content = document.getElementById('input-doc-content').value;

    if (!title || !content) return notify('Required', 'Please fill all fields', 'error');

    const endpoint = editingDocId ? 'updateDocument' : 'addDocument';
    const payload = editingDocId ? { id: editingDocId, title, content } : { title, content };

    fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).then(resp => resp.json()).then(success => {
        if (success) {
            notify('Success', editingDocId ? 'Document updated' : 'Document saved', 'success');
            closeDocModal();
            loadDocuments();
        }
    });
}

function showDocument(id) {
    fetch(`https://${GetParentResourceName()}/showDocToNearby`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id })
    }).then(() => {
        notify('Shared', 'Showing document to nearby citizens', 'success');
    });
}

function giveDocument(id) {
    fetch(`https://${GetParentResourceName()}/giveDocToNearby`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id })
    });
}

function deleteDocument(id) {
    openConfirmModal('Delete this document from official records?', () => {
        fetch(`https://${GetParentResourceName()}/deleteDocument`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
        }).then(() => {
            notify('Deleted', 'Document removed', 'success');
            loadDocuments();
        });
    });
}

// Viewer Logic
function openViewDoc(doc) {
    if (!doc) return console.error('No document data provided');
    
    console.log('Opening Document Viewer...', doc.title);
    const modal = document.getElementById('modal-view-doc');
    if (!modal) return;

    // Safety checks for all fields
    const docId = doc.id || doc.docId || 0;
    const docTitle = doc.title || 'Untitled Document';
    const docContent = doc.content || 'No content available.';
    const docAuthor = doc.author || 'Unknown Author';
    const docDate = doc.timestamp ? new Date(doc.timestamp).toLocaleDateString('en-GB') : new Date().toLocaleDateString('en-GB');

    modal.classList.remove('hidden');
    
    // Set content with fallback values
    document.getElementById('view-doc-id').innerText = '#GOV-' + docId.toString().padStart(4, '0');
    document.getElementById('view-doc-title').innerText = docTitle;
    document.getElementById('view-doc-content').innerText = docContent;
    document.getElementById('view-doc-author').innerText = docAuthor;
    document.getElementById('view-doc-date').innerText = docDate;
}

function closeViewDoc() {
    document.getElementById('modal-view-doc').classList.add('hidden');
    
    // Only release focus if the main MDT is NOT open
    const isMdtOpen = !document.getElementById('app').classList.contains('hidden');
    if (!isMdtOpen) {
        fetch(`https://${GetParentResourceName()}/closeViewer`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }
}

// Global Key Listeners
window.addEventListener('keyup', function(event) {
    if (event.key === 'Escape') {
        const viewer = document.getElementById('modal-view-doc');
        if (!viewer.classList.contains('hidden')) {
            closeViewDoc();
        } else if (!document.getElementById('modal-citizen-registration').classList.contains('hidden')) {
            closeCitizenRegistration();
        } else if (!document.getElementById('app').classList.contains('hidden')) {
            closeMDT();
        }
    }
});

// Citizen Registration UI (LARGE)
function openCitizenRegistrationNUI(data) {
    document.getElementById('modal-citizen-registration').classList.remove('hidden');
    document.getElementById('reg-doc-type').value = data.type;
    document.getElementById('reg-type-label').innerText = data.label;
    document.getElementById('reg-details').value = data.template;
    document.getElementById('reg-name').value = '';
}

function closeCitizenRegistration() {
    document.getElementById('modal-citizen-registration').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/closeRegistration`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function submitCitizenRegistration() {
    const type = document.getElementById('reg-doc-type').value;
    const name = document.getElementById('reg-name').value;
    const details = document.getElementById('reg-details').value;

    if (!name || !details) return notify('Required', 'Please fill all fields', 'error');

    fetch(`https://${GetParentResourceName()}/submitRegistration`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ type, name, details })
    }).then(resp => resp.json()).then(success => {
        if (success) {
            notify('Success', 'Your application has been filed', 'success');
            document.getElementById('modal-citizen-registration').classList.add('hidden');
            fetch(`https://${GetParentResourceName()}/closeRegistration`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        }
    });
}

// Add to existing message listener or create new one? 
// I'll add it to the top one later, but for now I'll use a second one or append.
// Actually, I'll just append a new listener for registration.
window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.action === 'openRegistration') {
        openCitizenRegistrationNUI(data);
    }
});
