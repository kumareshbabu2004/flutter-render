(() => {
  let startY;
  document.addEventListener('touchstart', (e) => {
    startY = e.touches[0].pageY;
  });

  document.addEventListener('touchmove', (e) => {
    const y = e.touches[0].pageY;
    const scrollTop = document.documentElement.scrollTop;
    
    if (scrollTop === 0) {
      const pullAmount = y - startY;
      if (pullAmount > REFRESH_THRESHOLD) {
        Flutter.postMessage('refresh');
      } else if (pullAmount > 0) {
        Flutter.postMessage('pull:' + pullAmount);
      }
    }
  });

  document.addEventListener('touchend', () => {
    Flutter.postMessage('pull:0');
  }); 
})(); 