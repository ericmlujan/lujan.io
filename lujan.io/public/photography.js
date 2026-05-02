document.addEventListener('DOMContentLoaded', function() {
  var container = document.querySelector('.gallery-container');
  if (!container) return;

  imagesLoaded(container, function() {
    new Masonry(container, {
      itemSelector: '.gallery-photo',
      columnWidth: '.gallery-sizer',
      gutter: '.gallery-gutter-sizer',
      percentPosition: true
    });
  });
});
