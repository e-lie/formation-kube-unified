<script>
  import './styles.css';
</script>

<div class="min-h-screen bg-gray-50">
  <nav class="bg-white shadow-sm">
    <div class="max-w-7xl mx-auto px-8 py-4">
      <div class="flex justify-between items-center">
        <a href="/" class="text-xl font-bold">Formation Terraform</a>
        <a href="/blog" class="text-blue-600 hover:text-blue-800">Tous les tutoriels</a>
      </div>
    </div>
  </nav>
  
  <main>
    <slot />
  </main>
  
  <footer class="bg-gray-100 mt-12">
    <div class="max-w-7xl mx-auto px-8 py-6 text-center text-gray-600">
      <p>Formation Terraform - Tutoriels pratiques</p>
    </div>
  </footer>
</div>