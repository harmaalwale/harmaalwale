document.addEventListener('DOMContentLoaded', function() {
    // Initialize page with Home by default
    if(window.location.pathname.endsWith('index.html') || 
       window.location.pathname === '/') {
        loadTabContent('home');
    }
    
    // Tab click handlers
    document.querySelectorAll('[data-tab]').forEach(tab => {
        tab.addEventListener('click', function(e) {
            e.preventDefault();
            const tabName = this.getAttribute('data-tab');
            loadTabContent(tabName);
            
            // Update active tab styling
            document.querySelectorAll('[data-tab]').forEach(t => 
                t.classList.remove('active'));
            this.classList.add('active');
        });
    });
});

function loadTabContent(tab) {
    const contentDiv = document.getElementById('page-content');
    
    const content = {
        'home': getHomeContent(),
        'mfd-spare': getMFDSpareContent(),
        'it-products': getComingSoonContent('IT Products'),
        'refurbished-mfds': getComingSoonContent('Refurbished MFDs'),
        'fashion': getComingSoonContent('Fashion'),
        'support': getSupportContent()
    };
    
    contentDiv.innerHTML = content[tab] || content['home'];
}

function getComingSoonContent(title) {
    return `
        <div class="coming-soon-page">
            <div class="coming-soon-content">
                <div class="coming-badge">
                    <span class="dot"></span>
                    COMING SOON
                </div>
                <h1>${title}</h1>
                <p>We're working hard to bring you amazing ${title.toLowerCase()} products.</p>
                <p>Stay tuned!</p>
            </div>
        </div>
    `;
}